import AppIntents
import Foundation
import WidgetKit
import FokusCore

// MARK: - Notification Name for Sync

public extension Notification.Name {
    nonisolated static let fokusExternalStateDidChange = Notification.Name("com.rifkygnwanz.fokus.externalStateDidChange")
}

// MARK: - TimerExternalSync

/// Menjalankan aksi timer dari luar aplikasi utama (Live Activity Intent / Notification Action / Widget)
/// dan menyinkronkan state melalui App Group + NotificationCenter + Darwin Notification + WidgetCenter.
public enum TimerExternalSync {

    public nonisolated static let darwinNotificationName = "com.rifkygnwanz.fokus.stateDidChange"
    public nonisolated static let appGroupSuiteName = "group.com.rifkygnwanz.fokus"

    @MainActor
    public static func performExternalAction(_ action: TimerAction) async {
        let store = AppGroupStateStore(suiteName: appGroupSuiteName)
        let currentState = (try? store.load()) ?? TimerState()
        let configuration = loadConfiguration()
        let engine = TimerEngine(configuration: configuration)
        let transition = engine.reduce(currentState, action, now: Date())

        try? store.save(transition.state)

        let isExt = Bundle.main.bundlePath.hasSuffix(".appex") || Bundle.main.infoDictionary?["NSExtension"] != nil
        let activityPresenter = ActivityKitPresenter(suiteName: appGroupSuiteName)
        let notificationScheduler = UserNotificationScheduler()

        for effect in transition.effects {
            switch effect {
            case .scheduleNotification(let date, let phase):
                try? await notificationScheduler.scheduleEndOfPhase(at: date, phase: phase)
            case .cancelNotifications:
                await notificationScheduler.cancelPending()
            case .startActivity(let state):
                if !isExt {
                    await activityPresenter.startActivity(state: state, configuration: configuration)
                } else {
                    await activityPresenter.updateActivity(state: state)
                }
            case .updateActivity(let state):
                await activityPresenter.updateActivity(state: state)
            case .endActivity:
                await activityPresenter.endActivity()
            case .persist(let state):
                try? store.save(state)
            case .record(let record):
                store.enqueuePendingRecord(record)
            case .haptic:
                break
            }
        }

        if !isExt {
            await notificationScheduler.syncActiveTimerNotification(state: transition.state)
        }
        notifyStateChanged()
        WidgetCenter.shared.reloadAllTimelines()
    }

    public nonisolated static func notifyStateChanged() {
        NotificationCenter.default.post(name: .fokusExternalStateDidChange, object: nil)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(darwinNotificationName as CFString),
            nil,
            nil,
            true
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func loadConfiguration() -> TimerConfiguration {
        let defaults = UserDefaults(suiteName: appGroupSuiteName) ?? .standard
        let focus = defaults.integer(forKey: "fokus.focusMinutes")
        let shortBreak = defaults.integer(forKey: "fokus.shortBreakMinutes")
        let longBreak = defaults.integer(forKey: "fokus.longBreakMinutes")
        let cycles = defaults.integer(forKey: "fokus.cyclesPerRound")
        let autoBreak = defaults.object(forKey: "fokus.autoStartBreaks") as? Bool ?? true
        let autoFocus = defaults.bool(forKey: "fokus.autoStartFocus")

        return TimerConfiguration(
            focusMinutes: focus == 0 ? 25 : focus,
            shortBreakMinutes: shortBreak == 0 ? 5 : shortBreak,
            longBreakMinutes: longBreak == 0 ? 15 : longBreak,
            cyclesPerRound: cycles == 0 ? 4 : cycles,
            autoStartBreaks: autoBreak,
            autoStartFocus: autoFocus
        )
    }
}

// MARK: - LiveActivityIntents & WidgetIntents

/// Intent untuk memulai timer langsung dari Widget / Live Activity / Shortcut.
public nonisolated struct StartTimerIntent: AppIntent, LiveActivityIntent {
    public static let title: LocalizedStringResource = "Mulai Timer"
    public static let description = IntentDescription("Memulai sesi timer Fokus.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        await TimerExternalSync.performExternalAction(.start(label: nil))
        return .result()
    }
}

/// Intent untuk menjeda timer langsung dari Live Activity / Dynamic Island / Widget.
public nonisolated struct PauseTimerIntent: AppIntent, LiveActivityIntent {
    public static let title: LocalizedStringResource = "Jeda Timer"
    public static let description = IntentDescription("Menjeda sesi timer Fokus yang sedang berjalan.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        await TimerExternalSync.performExternalAction(.pause)
        return .result()
    }
}

/// Intent untuk melanjutkan timer langsung dari Live Activity / Dynamic Island.
public nonisolated struct ResumeTimerIntent: AppIntent, LiveActivityIntent {
    public static let title: LocalizedStringResource = "Lanjutkan Timer"
    public static let description = IntentDescription("Melanjutkan sesi timer Fokus yang sedang dijeda.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        await TimerExternalSync.performExternalAction(.resume)
        return .result()
    }
}

/// Intent untuk melewati fase saat ini langsung dari Live Activity / Dynamic Island.
public nonisolated struct SkipTimerIntent: AppIntent, LiveActivityIntent {
    public static let title: LocalizedStringResource = "Lewati Fase"
    public static let description = IntentDescription("Melewati fase Fokus atau Istirahat saat ini.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        await TimerExternalSync.performExternalAction(.skip)
        return .result()
    }
}

/// Intent untuk menghentikan timer langsung dari Live Activity / Dynamic Island.
public nonisolated struct StopTimerIntent: AppIntent, LiveActivityIntent {
    public static let title: LocalizedStringResource = "Hentikan Timer"
    public static let description = IntentDescription("Menghentikan dan mereset sesi timer Fokus.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        await TimerExternalSync.performExternalAction(.stop)
        return .result()
    }
}
