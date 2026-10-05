import Foundation

// MARK: - TimerAction

/// Aksi yang bisa dikirim ke TimerEngine.
public enum TimerAction: Equatable, Sendable {
    case start(label: String?)
    case pause
    case resume
    case stop
    case skip
    /// Dipanggil saat endDate tercapai — fase berakhir secara alami.
    case phaseElapsed
}

// MARK: - HapticEvent

public enum HapticEvent: Equatable, Sendable {
    case light       // mulai / jeda
    case success     // fase selesai
    case warning     // berhenti / lewati
}

// MARK: - TimerEffect

/// Efek samping yang harus dijalankan oleh TimerCoordinator.
/// TimerEngine hanya menghasilkan nilai ini — tidak mengeksekusinya sendiri (S1).
public enum TimerEffect: Equatable, Sendable {
    case scheduleNotification(at: Date, phase: TimerPhase)
    case cancelNotifications
    case startActivity(TimerState)
    case updateActivity(TimerState)
    case endActivity
    case persist(TimerState)
    case record(SessionRecord)
    case haptic(HapticEvent)
}

// MARK: - Transition

/// Hasil dari TimerEngine.reduce: state baru + daftar efek yang harus dijalankan.
public struct Transition: Equatable, Sendable {
    public var state: TimerState
    public var effects: [TimerEffect]

    public init(state: TimerState, effects: [TimerEffect] = []) {
        self.state = state
        self.effects = effects
    }
}
