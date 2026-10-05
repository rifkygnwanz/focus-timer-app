import Foundation
import SwiftData
import UIKit
import WidgetKit
import FokusCore
import OSLog

// MARK: - TimerCoordinator

/// Satu-satunya tempat yang "kotor" — mengeksekusi efek dari TimerEngine.
/// Menerima Transition dari engine dan mendelegasikan setiap efek ke service yang sesuai.
@MainActor
public final class TimerCoordinator {

    // MARK: Dependencies

    private var engine: TimerEngine
    private let clock: any Clock
    private let notifications: any NotificationScheduling
    private let activity: any ActivityPresenting
    private let sessions: any SessionRecording
    private let store: any TimerStateStoring
    private let haptic: any HapticFeedbackProviding
    private let logger = Logger(subsystem: "com.rifkygnwanz.fokus", category: "coordinator")

    // MARK: Published State

    private(set) var currentState: TimerState
    private(set) var pendingConfiguration: TimerConfiguration?
    var onStateChange: ((TimerState) -> Void)?
    var onSessionRecorded: (() -> Void)?

    private var expirationTask: Task<Void, Never>?
    private var notificationObserver: NSObjectProtocol?

    // MARK: Init

    public init(
        engine: TimerEngine,
        clock: any Clock,
        notifications: any NotificationScheduling,
        activity: any ActivityPresenting,
        sessions: any SessionRecording,
        store: any TimerStateStoring,
        haptic: any HapticFeedbackProviding
    ) {
        self.engine = engine
        self.clock = clock
        self.notifications = notifications
        self.activity = activity
        self.sessions = sessions
        self.store = store
        self.haptic = haptic

        // FR-10: Muat state yang tersimpan saat app dibuka
        self.currentState = (try? store.load()) ?? TimerState()

        observeExternalChanges()
        scheduleExpirationTimerIfNeeded()
        syncIdleTimerDisabled()
    }

    // MARK: Update Configuration (BR-09)

    /// Memperbarui konfigurasi secara aman (BR-09):
    /// - Jika timer idle: langsung diterapkan.
    /// - Jika timer sedang berjalan/dijeda: durasi fase yang sedang berjalan dikunci agar progres & rekaman sesi tetap akurat,
    ///   sedangkan durasi fase berikutnya langsung siap digunakan saat transisi fase.
    public func updateConfiguration(_ newConfiguration: TimerConfiguration) {
        if currentState.isIdle {
            self.pendingConfiguration = nil
            self.engine = TimerEngine(configuration: newConfiguration)
            return
        }

        self.pendingConfiguration = newConfiguration
        let currentConfig = engine.configuration
        let safeActiveConfig = TimerConfiguration(
            focusMinutes: currentState.phase == .focus ? currentConfig.focusMinutes : newConfiguration.focusMinutes,
            shortBreakMinutes: currentState.phase == .shortBreak ? currentConfig.shortBreakMinutes : newConfiguration.shortBreakMinutes,
            longBreakMinutes: currentState.phase == .longBreak ? currentConfig.longBreakMinutes : newConfiguration.longBreakMinutes,
            cyclesPerRound: newConfiguration.cyclesPerRound,
            autoStartBreaks: newConfiguration.autoStartBreaks,
            autoStartFocus: newConfiguration.autoStartFocus
        )
        self.engine = TimerEngine(configuration: safeActiveConfig)
    }

    /// Menghentikan sesi yang sedang berjalan dan langsung menerapkan konfigurasi durasi baru sekarang juga.
    public func applyConfigurationAndReset(_ newConfiguration: TimerConfiguration) async {
        if !currentState.isIdle {
            await handle(.stop)
        }
        self.pendingConfiguration = nil
        self.engine = TimerEngine(configuration: newConfiguration)
        onStateChange?(currentState)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func syncIdleTimerDisabled() {
        let defaults = UserDefaults(suiteName: "group.com.rifkygnwanz.fokus") ?? .standard
        let keepScreenOn = defaults.object(forKey: SettingsKey.keepScreenOn.rawValue) as? Bool ?? true
        UIApplication.shared.isIdleTimerDisabled = keepScreenOn && currentState.isRunning
    }

    // MARK: Handle Action

    public func handle(_ action: TimerAction, at actionDate: Date? = nil) async {
        let effectiveNow = actionDate ?? clock.now
        let previousPhase = currentState.phase
        let transition = engine.reduce(currentState, action, now: effectiveNow)
        currentState = transition.state

        // Promosikan pendingConfiguration setelah fase sebelumnya selesai / dilewati / dihentikan
        if let pending = pendingConfiguration,
           currentState.isIdle || currentState.phase != previousPhase {
            self.engine = TimerEngine(configuration: pending)
            self.pendingConfiguration = nil
        }

        onStateChange?(currentState)
        scheduleExpirationTimerIfNeeded()
        syncIdleTimerDisabled()
        await executeEffects(transition.effects)

        if let userNotifications = notifications as? UserNotificationScheduler {
            await userNotifications.syncActiveTimerNotification(state: currentState)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Recover & Sync State (FR-10)

    /// Dipanggil saat app muncul ke foreground atau menerima perubahan dari intent/notifikasi.
    public func reconcileIfNeeded() async {
        reloadFromStoreIfDifferent()
        await flushPendingRecordsIfNeeded()
        syncIdleTimerDisabled()

        // Rekonsiliasi semua fase yang sudah melewati endDate selama app di background
        var safetyCounter = 0
        while case .running(let endDate) = currentState.status,
              clock.now >= endDate,
              safetyCounter < 10 {
            safetyCounter += 1
            logger.info("State stale terdeteksi — merekonsiliasi fase yang berakhir pada \(endDate)")
            await handle(.phaseElapsed, at: endDate)
        }

        scheduleExpirationTimerIfNeeded()
        if !currentState.isIdle {
            await activity.updateActivity(state: currentState)
        }
    }

    /// Memuat ulang state dari AppGroupStateStore jika diubah oleh LiveActivityIntent / Notification Action.
    public func reloadFromStoreIfDifferent() {
        guard let storedState = try? store.load() else { return }
        guard storedState != currentState else { return }
        currentState = storedState
        onStateChange?(currentState)
        scheduleExpirationTimerIfNeeded()
        syncIdleTimerDisabled()

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.flushPendingRecordsIfNeeded()
            if case .running(let endDate) = self.currentState.status {
                try? await self.notifications.scheduleEndOfPhase(at: endDate, phase: self.currentState.phase)
                await self.activity.startActivity(state: self.currentState, configuration: self.engine.configuration)
            } else if case .paused = self.currentState.status {
                await self.notifications.cancelPending()
                await self.activity.updateActivity(state: self.currentState)
            } else if self.currentState.isIdle {
                await self.notifications.cancelPending()
                await self.activity.endActivity()
            }
            if let userNotifications = self.notifications as? UserNotificationScheduler {
                await userNotifications.syncActiveTimerNotification(state: self.currentState)
            }
        }
    }

    /// Memindahkan rekaman sesi dari AppGroupStateStore (hasil aksi Live Activity) ke SwiftData lokal.
    public func flushPendingRecordsIfNeeded() async {
        guard let appGroupStore = store as? AppGroupStateStore else { return }
        let pendingRecords = appGroupStore.drainPendingRecords()
        guard !pendingRecords.isEmpty else { return }

        for record in pendingRecords {
            do {
                try await sessions.save(record)
            } catch {
                logger.error("Gagal menyimpan sesi tertunda: \(error.localizedDescription)")
            }
        }
        onSessionRecorded?()
    }

    // MARK: Private

    private func observeExternalChanges() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .fokusExternalStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.reloadFromStoreIfDifferent()
            }
        }

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let coordinator = Unmanaged<TimerCoordinator>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    coordinator.reloadFromStoreIfDifferent()
                }
            },
            TimerExternalSync.darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func scheduleExpirationTimerIfNeeded() {
        expirationTask?.cancel()
        expirationTask = nil

        guard case .running(let endDate) = currentState.status else { return }
        let remaining = endDate.timeIntervalSince(clock.now)

        guard remaining > 0 else {
            expirationTask = Task { @MainActor [weak self] in
                await self?.handle(.phaseElapsed)
            }
            return
        }

        expirationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            await self?.handle(.phaseElapsed)
        }
    }

    private func executeEffects(_ effects: [TimerEffect]) async {
        for effect in effects {
            await executeEffect(effect)
        }
    }

    private func executeEffect(_ effect: TimerEffect) async {
        switch effect {
        case .scheduleNotification(let date, let phase):
            do {
                try await notifications.scheduleEndOfPhase(at: date, phase: phase)
            } catch {
                logger.error("Gagal menjadwalkan notifikasi: \(error.localizedDescription)")
            }

        case .cancelNotifications:
            await notifications.cancelPending()

        case .startActivity(let state):
            await activity.startActivity(state: state, configuration: engine.configuration)

        case .updateActivity(let state):
            await activity.updateActivity(state: state)

        case .endActivity:
            await activity.endActivity()

        case .persist(let state):
            do {
                try store.save(state)
            } catch {
                logger.error("Gagal menyimpan state: \(error.localizedDescription)")
            }

        case .record(let record):
            do {
                try await sessions.save(record)
                onSessionRecorded?()
            } catch {
                logger.error("Gagal menyimpan sesi: \(error.localizedDescription)")
            }

        case .haptic(let event):
            haptic.trigger(event)
        }
    }
}
