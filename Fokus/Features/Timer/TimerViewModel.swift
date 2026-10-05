import Foundation
import FokusCore

// MARK: - TimerPresentation

/// Data tampilan yang dibutuhkan oleh TimerContent. Pure value type.
public struct TimerPresentation: Equatable {
    public let phase: TimerPhase
    public let cycleIndex: Int
    public let cyclesPerRound: Int
    public let statusLabel: String
    public let progress: Double     // 0...1 untuk ProgressRing
    public let endDate: Date?       // untuk Text(timerInterval:)
    public let remainingSeconds: TimeInterval  // saat paused
    public let isRunning: Bool
    public let isPaused: Bool
    public let isIdle: Bool
    public let label: String?

    public init(
        phase: TimerPhase,
        cycleIndex: Int,
        cyclesPerRound: Int,
        statusLabel: String,
        progress: Double,
        endDate: Date?,
        remainingSeconds: TimeInterval,
        isRunning: Bool,
        isPaused: Bool,
        isIdle: Bool,
        label: String?
    ) {
        self.phase = phase
        self.cycleIndex = cycleIndex
        self.cyclesPerRound = cyclesPerRound
        self.statusLabel = statusLabel
        self.progress = progress
        self.endDate = endDate
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
        self.isPaused = isPaused
        self.isIdle = isIdle
        self.label = label
    }
}

// MARK: - TimerActions

/// Closure actions — TimerContent hanya memanggil ini.
public struct TimerActions {
    public let onStart: (String?) -> Void
    public let onPause: () -> Void
    public let onResume: () -> Void
    public let onStop: () -> Void
    public let onSkip: () -> Void
}

// MARK: - TimerViewModel

/// Mengelola state layar Timer dan mendelegasikan aksi ke coordinator.
@Observable
@MainActor
public final class TimerViewModel {

    // MARK: State

    private(set) var presentation: TimerPresentation
    private(set) var showStopConfirmation: Bool = false
    private(set) var labelText: String = ""

    // MARK: Dependencies

    private let coordinator: TimerCoordinator
    private var configuration: TimerConfiguration
    var onStateChanged: ((TimerState) -> Void)?

    // MARK: Init

    public init(coordinator: TimerCoordinator, configuration: TimerConfiguration) {
        self.coordinator = coordinator
        self.configuration = configuration
        self.presentation = Self.makePresentation(
            from: coordinator.currentState,
            configuration: configuration
        )

        coordinator.onStateChange = { [weak self] state in
            guard let self else { return }
            self.presentation = Self.makePresentation(
                from: state,
                configuration: self.configuration
            )
            self.onStateChanged?(state)
        }
    }

    // MARK: Update Configuration (BR-09)

    /// Memperbarui konfigurasi dari Pengaturan.
    /// Jika timer idle, tampilan durasi langsung diperbarui; jika sedang berjalan/dijeda,
    /// durasi baru hanya berlaku untuk fase berikutnya (BR-09).
    public func updateConfiguration(_ newConfiguration: TimerConfiguration) {
        self.configuration = newConfiguration
        let state = coordinator.currentState
        if state.isIdle {
            self.presentation = Self.makePresentation(
                from: state,
                configuration: newConfiguration
            )
        } else {
            self.presentation = TimerPresentation(
                phase: presentation.phase,
                cycleIndex: presentation.cycleIndex,
                cyclesPerRound: newConfiguration.cyclesPerRound,
                statusLabel: presentation.statusLabel,
                progress: presentation.progress,
                endDate: presentation.endDate,
                remainingSeconds: presentation.remainingSeconds,
                isRunning: presentation.isRunning,
                isPaused: presentation.isPaused,
                isIdle: presentation.isIdle,
                label: presentation.label
            )
        }
    }

    // MARK: Actions

    var actions: TimerActions {
        TimerActions(
            onStart: { [weak self] label in
                Task { await self?.coordinator.handle(.start(label: label)) }
            },
            onPause: { [weak self] in
                Task { await self?.coordinator.handle(.pause) }
            },
            onResume: { [weak self] in
                Task { await self?.coordinator.handle(.resume) }
            },
            onStop: { [weak self] in
                Task { await self?.coordinator.handle(.stop) }
            },
            onSkip: { [weak self] in
                Task { await self?.coordinator.handle(.skip) }
            }
        )
    }

    func reconcile() async {
        await coordinator.reconcileIfNeeded()
    }

    // MARK: Private

    private static func makePresentation(
        from state: TimerState,
        configuration: TimerConfiguration
    ) -> TimerPresentation {
        let totalDuration = configuration.duration(for: state.phase)

        let (progress, endDate, remainingSeconds): (Double, Date?, TimeInterval) = {
            switch state.status {
            case .idle:
                return (1.0, nil, totalDuration)
            case .running(let end):
                let remaining = max(0, end.timeIntervalSinceNow)
                let prog = remaining / totalDuration
                return (prog, end, remaining)
            case .paused(let remaining):
                let prog = remaining / totalDuration
                return (prog, nil, remaining)
            }
        }()

        return TimerPresentation(
            phase: state.phase,
            cycleIndex: state.cycleIndex,
            cyclesPerRound: configuration.cyclesPerRound,
            statusLabel: "",
            progress: min(1, max(0, progress)),
            endDate: endDate,
            remainingSeconds: remainingSeconds,
            isRunning: state.isRunning,
            isPaused: state.isPaused,
            isIdle: state.isIdle,
            label: state.label
        )
    }
}
