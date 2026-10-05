import ActivityKit
import Foundation
import FokusCore
import OSLog

// MARK: - ActivityKitPresenter

/// Implementasi konkret ActivityPresenting menggunakan ActivityKit.
/// Mengelola siklus hidup Live Activity & Dynamic Island secara idempoten (S8).
public final class ActivityKitPresenter: ActivityPresenting {

    private let logger = Logger(subsystem: "com.rifkygnwanz.fokus", category: "activity")
    private let suiteName: String

    public nonisolated init(suiteName: String = "group.com.rifkygnwanz.fokus") {
        self.suiteName = suiteName
    }

    public func startActivity(state: TimerState, configuration: TimerConfiguration) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activity dinonaktifkan oleh pengguna atau sistem")
            return
        }

        guard let contentState = FokusActivityAttributes.ContentState.from(
            state: state,
            configuration: configuration
        ) else {
            await endActivity()
            return
        }

        let attributes = FokusActivityAttributes(
            label: state.label,
            cyclesPerRound: configuration.cyclesPerRound
        )
        let content = ActivityContent(state: contentState, staleDate: staleDate(for: state))

        // S8: Idempoten — jika sudah ada activity aktif, perbarui yang ada dan bersihkan sisanya
        let existingActivities = Activity<FokusActivityAttributes>.activities
        if let primary = existingActivities.first {
            await primary.update(content)
            for extra in existingActivities.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            logger.debug("Live Activity yang sudah ada diperbarui untuk fase \(state.phase.rawValue)")
            return
        }

        guard !Bundle.main.bundlePath.hasSuffix(".appex") else {
            logger.debug("Activity.request dilewati: tidak didukung di dalam ekstensi")
            return
        }

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            logger.info("Live Activity dimulai untuk fase \(state.phase.rawValue)")
        } catch {
            logger.error("Gagal memulai Live Activity: \(error.localizedDescription)")
        }
    }

    public func updateActivity(state: TimerState) async {
        let configuration = loadConfiguration()
        guard let contentState = FokusActivityAttributes.ContentState.from(
            state: state,
            configuration: configuration
        ) else {
            await endActivity()
            return
        }

        let content = ActivityContent(state: contentState, staleDate: staleDate(for: state))
        let existingActivities = Activity<FokusActivityAttributes>.activities

        if existingActivities.isEmpty {
            await startActivity(state: state, configuration: configuration)
            return
        }

        for activity in existingActivities {
            await activity.update(content)
        }
        logger.debug("Live Activity diperbarui: statusRunning=\(state.isRunning)")
    }

    public func endActivity() async {
        let existingActivities = Activity<FokusActivityAttributes>.activities
        for activity in existingActivities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        if !existingActivities.isEmpty {
            logger.info("Semua Live Activity dihentikan")
        }
    }

    // MARK: - Helpers

    private func staleDate(for state: TimerState) -> Date? {
        if case .running(let endDate) = state.status {
            return endDate
        }
        return nil
    }

    private func loadConfiguration() -> TimerConfiguration {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
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
