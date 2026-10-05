import Foundation
import SwiftData
import FokusCore

// MARK: - AppContainer

/// Composition root. Satu-satunya tempat yang mengenal semua implementasi konkret.
/// Tidak ada singleton. Semua dependensi dirakit di sini dan disebarkan lewat init. (S4, D12)
@MainActor
public final class AppContainer {

    // MARK: Exposed

    let timerCoordinator: TimerCoordinator
    let timerViewModel: TimerViewModel
    let settingsViewModel: SettingsViewModel
    let statsViewModel: StatsViewModel
    let notificationScheduler: UserNotificationScheduler
    let modelContainer: ModelContainer

    // MARK: Init

    private init(
        timerCoordinator: TimerCoordinator,
        timerViewModel: TimerViewModel,
        settingsViewModel: SettingsViewModel,
        statsViewModel: StatsViewModel,
        notificationScheduler: UserNotificationScheduler,
        modelContainer: ModelContainer
    ) {
        self.timerCoordinator = timerCoordinator
        self.timerViewModel = timerViewModel
        self.settingsViewModel = settingsViewModel
        self.statsViewModel = statsViewModel
        self.notificationScheduler = notificationScheduler
        self.modelContainer = modelContainer
    }

    // MARK: Factory

    public static func live() throws -> AppContainer {
        // --- Infrastruktur dasar ---
        let clock = SystemClock()
        let store = AppGroupStateStore()
        let notificationScheduler = UserNotificationScheduler()
        let haptic = UIKitHapticProvider()
        let activity = ActivityKitPresenter()

        // --- SwiftData ---
        let schema = Schema([FocusSessionModel.self])
        let modelConfig = ModelConfiguration(
            schema: schema,
            url: appGroupModelURL(),
            cloudKitDatabase: .none
        )
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfig])
        let modelContext = modelContainer.mainContext
        let sessionRepo = SwiftDataSessionRepository(modelContext: modelContext)

        // --- Domain ---
        let settings = SettingsViewModel()
        let configuration = settings.configuration
        let engine = TimerEngine(configuration: configuration)

        let coordinator = TimerCoordinator(
            engine: engine,
            clock: clock,
            notifications: notificationScheduler,
            activity: activity,
            sessions: sessionRepo,
            store: store,
            haptic: haptic
        )

        let timerViewModel = TimerViewModel(
            coordinator: coordinator,
            configuration: configuration
        )

        let statsViewModel = StatsViewModel(
            sessions: sessionRepo,
            locale: settings.selectedLanguage.locale
        )

        // --- Integrasi Antar Fitur ---

        // Sinkronisasi awal status timer aktif di Pengaturan
        settings.syncTimerActiveState(
            isActive: !coordinator.currentState.isIdle,
            hasPending: coordinator.pendingConfiguration != nil
        )

        timerViewModel.onStateChanged = { [weak settings, weak coordinator] state in
            settings?.syncTimerActiveState(
                isActive: !state.isIdle,
                hasPending: coordinator?.pendingConfiguration != nil
            )
        }

        // 1. Aksi dari tombol notifikasi langsung ke TimerCoordinator
        notificationScheduler.onActionReceived = { [weak coordinator] action in
            await coordinator?.handle(action)
        }

        // 2. Perubahan durasi & perilaku di Pengaturan memperbarui Engine & TimerViewModel secara aman (BR-09)
        settings.onConfigurationChanged = { [weak coordinator, weak timerViewModel] newConfig in
            coordinator?.updateConfiguration(newConfig)
            timerViewModel?.updateConfiguration(newConfig)
        }

        // 2b. Opsi "Terapkan Sekarang (Reset Timer Aktif)" dari Pengaturan
        settings.onApplyConfigurationAndReset = { [weak coordinator, weak timerViewModel] newConfig in
            await coordinator?.applyConfigurationAndReset(newConfig)
            timerViewModel?.updateConfiguration(newConfig)
        }

        // 3. Pengaturan "Jaga layar tetap menyala"
        settings.onKeepScreenOnChanged = { [weak coordinator] _ in
            coordinator?.syncIdleTimerDisabled()
        }

        // 4. Umpan balik langsung saat Haptic diaktifkan di Pengaturan
        settings.onHapticChanged = { enabled in
            if enabled {
                haptic.trigger(.light)
            }
        }

        // 5. Hapus semua riwayat dari Pengaturan menyinkronkan layar Statistik
        settings.onClearHistory = { [weak statsViewModel] in
            await statsViewModel?.deleteAll()
        }

        // 5b. Perubahan bahasa menyinkronkan format statistik dan tombol notifikasi interaktif
        settings.onLanguageChanged = { [weak statsViewModel, weak notificationScheduler] lang in
            statsViewModel?.updateLocale(lang.locale)
            notificationScheduler?.configureCategoriesAndDelegate()
        }

        // 6. Saat sesi selesai/direkam oleh TimerCoordinator, perbarui Statistik
        coordinator.onSessionRecorded = { [weak statsViewModel] in
            Task { @MainActor in
                await statsViewModel?.load()
            }
        }

        // Minta izin notifikasi & sinkronkan rekaman sesi + statistik sejak awal
        Task { @MainActor in
            await coordinator.reconcileIfNeeded()
            await statsViewModel.load()
            _ = await notificationScheduler.requestAuthorization()
        }

        return AppContainer(
            timerCoordinator: coordinator,
            timerViewModel: timerViewModel,
            settingsViewModel: settings,
            statsViewModel: statsViewModel,
            notificationScheduler: notificationScheduler,
            modelContainer: modelContainer
        )
    }

    // MARK: - Helpers

    private static func appGroupModelURL() -> URL {
        let groupID = "group.com.rifkygnwanz.fokus"
        let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)
            ?? FileManager.default.temporaryDirectory
        return containerURL.appendingPathComponent("fokus.sqlite")
    }
}
