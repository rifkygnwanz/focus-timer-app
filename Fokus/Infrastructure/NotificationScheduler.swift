import ActivityKit
import Foundation
import UserNotifications
import FokusCore
import OSLog

// MARK: - NotificationIdentifiers

public nonisolated enum NotificationIdentifier {
    public static let phaseEnd = "fokus.phaseEnd"
    public static let activeTimer = "fokus.activeTimer"

    public static let runningCategory = "FOKUS_RUNNING_CATEGORY"
    public static let pausedCategory = "FOKUS_PAUSED_CATEGORY"
    public static let phaseEndCategory = "FOKUS_PHASE_END_CATEGORY"

    public static let actionPause = "fokus.action.pause"
    public static let actionResume = "fokus.action.resume"
    public static let actionSkip = "fokus.action.skip"
    public static let actionStop = "fokus.action.stop"
    public static let actionStart = "fokus.action.start"
}

// MARK: - UserNotificationScheduler

/// Adapter notifikasi lokal interaktif. Implementasi NotificationScheduling & UNUserNotificationCenterDelegate.
public final class UserNotificationScheduler: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.rifkygnwanz.fokus", category: "notifications")
    private let notificationCenter = UNUserNotificationCenter.current()

    /// Callback saat pengguna menekan tombol aksi di notifikasi.
    public var onActionReceived: (@MainActor @Sendable (TimerAction) async -> Void)?

    public nonisolated override init() {
        super.init()
        configureCategoriesAndDelegate()
    }

    // MARK: - Setup Categories & Delegate

    private var activeLocale: Locale {
        let defaults = UserDefaults(suiteName: "group.com.rifkygnwanz.fokus") ?? .standard
        let langCode = defaults.string(forKey: "fokus.appLanguage") ?? "system"
        switch langCode {
        case "id":
            return Locale(identifier: "id")
        case "en":
            return Locale(identifier: "en")
        default:
            return .autoupdatingCurrent
        }
    }

    private static var isExtension: Bool {
        Bundle.main.bundlePath.hasSuffix(".appex") || Bundle.main.infoDictionary?["NSExtension"] != nil
    }

    public nonisolated func configureCategoriesAndDelegate() {
        guard !Self.isExtension else { return }
        let loc = activeLocale
        let pauseAction = UNNotificationAction(
            identifier: NotificationIdentifier.actionPause,
            title: String(localized: "Jeda", locale: loc),
            options: []
        )
        let resumeAction = UNNotificationAction(
            identifier: NotificationIdentifier.actionResume,
            title: String(localized: "Lanjut", locale: loc),
            options: []
        )
        let skipAction = UNNotificationAction(
            identifier: NotificationIdentifier.actionSkip,
            title: String(localized: "Lewati", locale: loc),
            options: []
        )
        let stopAction = UNNotificationAction(
            identifier: NotificationIdentifier.actionStop,
            title: String(localized: "Berhenti", locale: loc),
            options: [.destructive]
        )
        let startAction = UNNotificationAction(
            identifier: NotificationIdentifier.actionStart,
            title: String(localized: "Mulai", locale: loc),
            options: [.foreground]
        )

        let runningCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.runningCategory,
            actions: [pauseAction, skipAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let pausedCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.pausedCategory,
            actions: [resumeAction, skipAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let phaseEndCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.phaseEndCategory,
            actions: [startAction, skipAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([
            runningCategory,
            pausedCategory,
            phaseEndCategory,
        ])
        notificationCenter.delegate = self
    }

    // MARK: - NotificationScheduling

    public func scheduleEndOfPhase(at date: Date, phase: TimerPhase) async throws {
        if !Self.isExtension {
            _ = await requestAuthorization()
        } else {
            let settings = await notificationCenter.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        }
        await cancelPending()

        let defaults = UserDefaults(suiteName: "group.com.rifkygnwanz.fokus") ?? .standard
        let soundOption = defaults.string(forKey: "fokus.soundOption")
        let content = UNMutableNotificationContent()
        content.sound = (soundOption == "silent") ? nil : .default
        content.categoryIdentifier = NotificationIdentifier.phaseEndCategory
        content.interruptionLevel = .timeSensitive

        let loc = activeLocale
        switch phase {
        case .focus:
            content.title = String(localized: "Sesi fokus selesai", locale: loc)
            content.body = String(localized: "Waktunya istirahat.", locale: loc)
        case .shortBreak:
            content.title = String(localized: "Istirahat selesai", locale: loc)
            content.body = String(localized: "Siap fokus lagi?", locale: loc)
        case .longBreak:
            content.title = String(localized: "Istirahat panjang selesai", locale: loc)
            content.body = String(localized: "Siklus baru menunggu.", locale: loc)
        }

        let delay = date.timeIntervalSinceNow
        guard delay > 0 else {
            logger.debug("Notifikasi dilewati: delay \(delay)s sudah lewat")
            return
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.phaseEnd,
            content: content,
            trigger: trigger
        )
        try await notificationCenter.add(request)
        logger.debug("Notifikasi akhir fase dijadwalkan dalam \(delay)s untuk \(phase.rawValue)")
    }

    public func cancelPending() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            NotificationIdentifier.phaseEnd,
        ])
        logger.debug("Notifikasi akhir fase pending dibatalkan")
    }

    // MARK: - Ongoing / Status Notification

    /// Menampilkan atau memperbarui notifikasi status saat timer berjalan atau dijeda,
    /// lengkap dengan tombol aksi interaktif (Jeda, Lanjut, Lewati, Berhenti).
    public func syncActiveTimerNotification(state: TimerState) async {
        guard !Self.isExtension else { return }
        // Saat idle, atau saat sedang berjalan dan Live Activity sudah aktif, bersihkan notifikasi status
        if state.isIdle || (state.isRunning && ActivityAuthorizationInfo().areActivitiesEnabled) {
            clearActiveTimerNotification()
            return
        }

        let granted = await requestAuthorization()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.sound = nil
        content.interruptionLevel = .active

        let loc = activeLocale
        let phaseTitle = phaseDisplayName(for: state.phase, locale: loc)
        switch state.status {
        case .idle:
            return
        case .running(let endDate):
            let timeString = endDate.formatted(date: .omitted, time: .shortened)
            let runningFormat = String(localized: "%@ sedang berjalan", locale: loc)
            content.title = String(format: runningFormat, phaseTitle)
            if let label = state.label, !label.isEmpty {
                content.subtitle = label
            }
            let targetFormat = String(localized: "Target selesai pukul %@. Ketuk untuk jeda, atau tekan tahan untuk opsi lainnya.", locale: loc)
            content.body = String(format: targetFormat, timeString)
            content.categoryIdentifier = NotificationIdentifier.runningCategory

        case .paused(let remaining):
            let formatted = formatRemaining(remaining)
            let pausedFormat = String(localized: "%@ dijeda (%@)", locale: loc)
            content.title = String(format: pausedFormat, phaseTitle, formatted)
            if let label = state.label, !label.isEmpty {
                content.subtitle = label
            }
            content.body = String(localized: "Ketuk notifikasi ini untuk melanjutkan timer, atau tekan tahan untuk Lewati / Berhenti.", locale: loc)
            content.categoryIdentifier = NotificationIdentifier.pausedCategory
        }

        notificationCenter.removeDeliveredNotifications(withIdentifiers: [
            NotificationIdentifier.activeTimer,
        ])

        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.activeTimer,
            content: content,
            trigger: nil
        )
        do {
            try await notificationCenter.add(request)
        } catch {
            logger.error("Gagal menampilkan notifikasi status timer: \(error.localizedDescription)")
        }
    }

    public func clearActiveTimerNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            NotificationIdentifier.activeTimer,
        ])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [
            NotificationIdentifier.activeTimer,
        ])
    }

    public func requestAuthorization() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            return true
        }
        guard !Self.isExtension else { return false }
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            logger.info("Izin notifikasi: \(granted)")
            return granted
        } catch {
            logger.error("Gagal meminta izin notifikasi: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier == NotificationIdentifier.activeTimer {
            completionHandler([.banner, .list])
        } else {
            completionHandler([.banner, .list, .sound])
        }
    }

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let categoryIdentifier = response.notification.request.content.categoryIdentifier

        let mappedAction: TimerAction? = switch actionIdentifier {
        case NotificationIdentifier.actionPause:
            .pause
        case NotificationIdentifier.actionResume:
            .resume
        case NotificationIdentifier.actionSkip:
            .skip
        case NotificationIdentifier.actionStop:
            .stop
        case NotificationIdentifier.actionStart:
            .start(label: nil)
        case UNNotificationDefaultActionIdentifier:
            switch categoryIdentifier {
            case NotificationIdentifier.pausedCategory:
                .resume
            case NotificationIdentifier.runningCategory:
                .pause
            case NotificationIdentifier.phaseEndCategory:
                .start(label: nil)
            default:
                nil
            }
        default:
            nil
        }

        // UIKit memanggil delegate ini di main thread dan mewajibkan completionHandler()
        // dipanggil di main thread. Memanggilnya secara sinkron di sini mencegah crash
        // 'Call must be made on main thread' akibat async bridging Swift.
        completionHandler()

        guard let action = mappedAction else { return }

        Task { @MainActor in
            if let handler = self.onActionReceived {
                await handler(action)
            } else {
                await TimerExternalSync.performExternalAction(action)
            }
        }
    }

    // MARK: - Helpers

    private func phaseDisplayName(for phase: TimerPhase, locale: Locale) -> String {
        switch phase {
        case .focus: String(localized: "Fokus", locale: locale)
        case .shortBreak: String(localized: "Istirahat Pendek", locale: locale)
        case .longBreak: String(localized: "Istirahat Panjang", locale: locale)
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
