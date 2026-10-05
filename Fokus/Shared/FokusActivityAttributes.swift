import ActivityKit
import Foundation
import FokusCore

// MARK: - FokusActivityAttributes

/// Model atribut dan state dinamis untuk Live Activity & Dynamic Island.
/// Digunakan bersama oleh target aplikasi utama dan FokusWidgetExtension.
public nonisolated struct FokusActivityAttributes: ActivityAttributes, Sendable {

    public nonisolated struct ContentState: Codable, Hashable, Sendable {
        public nonisolated enum Timing: Codable, Hashable, Sendable {
            case running(start: Date, end: Date)
            case paused(remaining: TimeInterval)
        }

        public var phase: TimerPhase
        public var timing: Timing
        public var cycleIndex: Int
        public var totalDuration: TimeInterval

        public init(
            phase: TimerPhase,
            timing: Timing,
            cycleIndex: Int,
            totalDuration: TimeInterval
        ) {
            self.phase = phase
            self.timing = timing
            self.cycleIndex = cycleIndex
            self.totalDuration = totalDuration
        }

        public var isRunning: Bool {
            if case .running = timing { return true }
            return false
        }

        public var isPaused: Bool {
            if case .paused = timing { return true }
            return false
        }

        public static func from(
            state: TimerState,
            configuration: TimerConfiguration,
            now: Date = Date()
        ) -> ContentState? {
            let totalDuration = configuration.duration(for: state.phase)
            switch state.status {
            case .idle:
                return nil
            case .running(let endDate):
                let remaining = max(0, endDate.timeIntervalSince(now))
                let effectiveStart = endDate.addingTimeInterval(-totalDuration)
                let start = remaining > 0 ? effectiveStart : now
                return ContentState(
                    phase: state.phase,
                    timing: .running(start: start, end: endDate),
                    cycleIndex: state.cycleIndex,
                    totalDuration: totalDuration
                )
            case .paused(let remaining):
                return ContentState(
                    phase: state.phase,
                    timing: .paused(remaining: remaining),
                    cycleIndex: state.cycleIndex,
                    totalDuration: totalDuration
                )
            }
        }
    }

    public var label: String?
    public var cyclesPerRound: Int

    public init(label: String?, cyclesPerRound: Int) {
        self.label = label
        self.cyclesPerRound = cyclesPerRound
    }
}
