import Foundation

// MARK: - TimerPhase

/// Fase timer yang sedang atau akan berjalan.
public enum TimerPhase: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case focus
    case shortBreak
    case longBreak
}

// MARK: - TimerState

/// State tunggal timer. Satu-satunya sumber kebenaran waktu.
///
/// Kombinasi mustahil tidak dapat dibuat: `running` selalu punya `endDate`,
/// `paused` selalu punya `remaining` — tidak pernah terbalik (S7).
public struct TimerState: Codable, Equatable, Sendable {

    // MARK: Status

    public enum Status: Codable, Equatable, Sendable {
        case idle
        case running(endDate: Date)
        case paused(remaining: TimeInterval)
    }

    // MARK: Properties

    public var phase: TimerPhase
    public var status: Status
    public var cycleIndex: Int
    public var startedAt: Date?
    public var label: String?

    // MARK: Init

    public init(
        phase: TimerPhase = .focus,
        status: Status = .idle,
        cycleIndex: Int = 1,
        startedAt: Date? = nil,
        label: String? = nil
    ) {
        self.phase = phase
        self.status = status
        self.cycleIndex = cycleIndex
        self.startedAt = startedAt
        self.label = label
    }

    // MARK: Computed

    public var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = status { return true }
        return false
    }

    public var isIdle: Bool {
        if case .idle = status { return true }
        return false
    }
}

// MARK: - SessionRecord

/// Rekaman sesi yang sudah selesai atau dibatalkan. Tipe murni domain.
public struct SessionRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let phase: TimerPhase
    public let label: String?
    public let startedAt: Date
    public let endedAt: Date
    public let plannedSeconds: Int
    public let actualSeconds: Int
    public let outcome: SessionOutcome
    public let cycleIndex: Int

    public init(
        id: UUID = UUID(),
        phase: TimerPhase,
        label: String?,
        startedAt: Date,
        endedAt: Date,
        plannedSeconds: Int,
        actualSeconds: Int,
        outcome: SessionOutcome,
        cycleIndex: Int
    ) {
        self.id = id
        self.phase = phase
        self.label = label
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.outcome = outcome
        self.cycleIndex = cycleIndex
    }
}

public enum SessionOutcome: String, Codable, Equatable, Sendable {
    case completed
    case cancelled
}

// MARK: - TimerConfiguration

/// Konfigurasi durasi dan perilaku timer.
public struct TimerConfiguration: Equatable, Sendable {
    public var focusMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public var cyclesPerRound: Int
    public var autoStartBreaks: Bool
    public var autoStartFocus: Bool

    public static let `default` = TimerConfiguration(
        focusMinutes: 25,
        shortBreakMinutes: 5,
        longBreakMinutes: 15,
        cyclesPerRound: 4,
        autoStartBreaks: true,
        autoStartFocus: false
    )

    public init(
        focusMinutes: Int = 25,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 15,
        cyclesPerRound: Int = 4,
        autoStartBreaks: Bool = true,
        autoStartFocus: Bool = false
    ) {
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.cyclesPerRound = cyclesPerRound
        self.autoStartBreaks = autoStartBreaks
        self.autoStartFocus = autoStartFocus
    }

    public func duration(for phase: TimerPhase) -> TimeInterval {
        switch phase {
        case .focus: Double(focusMinutes) * 60
        case .shortBreak: Double(shortBreakMinutes) * 60
        case .longBreak: Double(longBreakMinutes) * 60
        }
    }
}
