import Foundation

// MARK: - TimerEngine

/// Fungsi murni yang menerapkan aturan bisnis timer.
///
/// - Tidak punya efek samping.
/// - Tidak memanggil `Date()` — menerima `now` sebagai parameter.
/// - Mudah diuji: `engine.reduce(state, .pause, now: fixedDate)`.
public struct TimerEngine: Sendable {

    public let configuration: TimerConfiguration

    public init(configuration: TimerConfiguration) {
        self.configuration = configuration
    }

    /// Menerapkan aksi pada state saat ini dan mengembalikan state baru beserta efek.
    public func reduce(_ state: TimerState, _ action: TimerAction, now: Date) -> Transition {
        switch action {
        case .start(let label):
            return handleStart(state, label: label, now: now)
        case .pause:
            return handlePause(state, now: now)
        case .resume:
            return handleResume(state, now: now)
        case .stop:
            return handleStop(state, now: now)
        case .skip:
            return handleSkip(state, now: now)
        case .phaseElapsed:
            return handlePhaseElapsed(state, now: now)
        }
    }

    // MARK: - Private Handlers

    private func handleStart(_ state: TimerState, label: String?, now: Date) -> Transition {
        guard state.isIdle else { return Transition(state: state) }

        let duration = configuration.duration(for: state.phase)
        let endDate = now.addingTimeInterval(duration)
        var newState = state
        newState.status = .running(endDate: endDate)
        newState.startedAt = now
        newState.label = label

        return Transition(
            state: newState,
            effects: [
                .scheduleNotification(at: endDate, phase: state.phase),
                .startActivity(newState),
                .persist(newState),
                .haptic(.light),
            ]
        )
    }

    private func handlePause(_ state: TimerState, now: Date) -> Transition {
        guard case .running(let endDate) = state.status else {
            return Transition(state: state)
        }

        let remaining = max(0, endDate.timeIntervalSince(now))
        var newState = state
        newState.status = .paused(remaining: remaining)

        return Transition(
            state: newState,
            effects: [
                .cancelNotifications,
                .updateActivity(newState),
                .persist(newState),
                .haptic(.light),
            ]
        )
    }

    private func handleResume(_ state: TimerState, now: Date) -> Transition {
        guard case .paused(let remaining) = state.status else {
            return Transition(state: state)
        }

        let endDate = now.addingTimeInterval(remaining)
        var newState = state
        newState.status = .running(endDate: endDate)

        return Transition(
            state: newState,
            effects: [
                .scheduleNotification(at: endDate, phase: state.phase),
                .updateActivity(newState),
                .persist(newState),
                .haptic(.light),
            ]
        )
    }

    private func handleStop(_ state: TimerState, now: Date) -> Transition {
        guard !state.isIdle else { return Transition(state: state) }

        let actualSeconds = calculateActualSeconds(state: state, now: now)
        var effects: [TimerEffect] = [
            .cancelNotifications,
            .endActivity,
            .haptic(.warning),
        ]

        // BR-04: não salvar sesi yang terlalu singkat
        if actualSeconds >= 60, let startedAt = state.startedAt {
            let record = SessionRecord(
                phase: state.phase,
                label: state.label,
                startedAt: startedAt,
                endedAt: now,
                plannedSeconds: Int(configuration.duration(for: state.phase)),
                actualSeconds: actualSeconds,
                outcome: .cancelled,
                cycleIndex: state.cycleIndex
            )
            effects.append(.record(record))
        }

        let newState = TimerState(
            phase: .focus,
            status: .idle,
            cycleIndex: 1
        )
        effects.append(.persist(newState))

        return Transition(state: newState, effects: effects)
    }

    private func handleSkip(_ state: TimerState, now: Date) -> Transition {
        guard !state.isIdle else { return Transition(state: state) }

        let actualSeconds = calculateActualSeconds(state: state, now: now)
        var recordedSession: SessionRecord?
        if state.phase == .focus, actualSeconds >= 60, let startedAt = state.startedAt {
            recordedSession = SessionRecord(
                phase: state.phase,
                label: state.label,
                startedAt: startedAt,
                endedAt: now,
                plannedSeconds: Int(configuration.duration(for: state.phase)),
                actualSeconds: actualSeconds,
                outcome: .cancelled,
                cycleIndex: state.cycleIndex
            )
        }

        let nextPhase = computeNextPhase(currentPhase: state.phase, cycleIndex: state.cycleIndex)
        let nextCycleIndex = computeNextCycleIndex(
            currentPhase: state.phase,
            currentCycleIndex: state.cycleIndex
        )

        var newState = TimerState(
            phase: nextPhase,
            status: .idle,
            cycleIndex: nextCycleIndex
        )

        var effects: [TimerEffect] = [
            .cancelNotifications,
            .endActivity,
            .persist(newState),
            .haptic(.warning),
        ]

        // Auto-start istirahat jika dikonfigurasi (BR-06)
        if isBreak(nextPhase) && configuration.autoStartBreaks {
            let duration = configuration.duration(for: nextPhase)
            let endDate = now.addingTimeInterval(duration)
            newState.status = .running(endDate: endDate)
            newState.startedAt = now
            effects = [
                .cancelNotifications,
                .scheduleNotification(at: endDate, phase: nextPhase),
                .startActivity(newState),
                .persist(newState),
                .haptic(.warning),
            ]
        }

        if let recordedSession {
            effects.append(.record(recordedSession))
        }

        return Transition(state: newState, effects: effects)
    }

    private func handlePhaseElapsed(_ state: TimerState, now: Date) -> Transition {
        guard case .running(let endDate) = state.status,
              let startedAt = state.startedAt else {
            return Transition(state: state)
        }

        let plannedSeconds = Int(configuration.duration(for: state.phase))
        let actualSeconds = plannedSeconds

        // Catat sesi yang selesai (BR-03)
        let record = SessionRecord(
            phase: state.phase,
            label: state.label,
            startedAt: startedAt,
            endedAt: endDate,
            plannedSeconds: plannedSeconds,
            actualSeconds: actualSeconds,
            outcome: .completed,
            cycleIndex: state.cycleIndex
        )

        let nextPhase = computeNextPhase(
            currentPhase: state.phase,
            cycleIndex: state.cycleIndex
        )
        let nextCycleIndex = computeNextCycleIndex(
            currentPhase: state.phase,
            currentCycleIndex: state.cycleIndex
        )

        // Jika LongBreak selesai → kembali ke Idle (FR-01)
        if state.phase == .longBreak {
            let idleState = TimerState(phase: .focus, status: .idle, cycleIndex: 1)
            return Transition(
                state: idleState,
                effects: [
                    .record(record),
                    .endActivity,
                    .persist(idleState),
                    .haptic(.success),
                ]
            )
        }

        var newState = TimerState(
            phase: nextPhase,
            status: .idle,
            cycleIndex: nextCycleIndex
        )

        var effects: [TimerEffect] = [
            .record(record),
            .haptic(.success),
        ]

        // Auto-start istirahat (BR-06)
        if isBreak(nextPhase) && configuration.autoStartBreaks {
            let duration = configuration.duration(for: nextPhase)
            let breakEndDate = now.addingTimeInterval(duration)
            newState.status = .running(endDate: breakEndDate)
            newState.startedAt = now
            effects += [
                .scheduleNotification(at: breakEndDate, phase: nextPhase),
                .updateActivity(newState),
                .persist(newState),
            ]
        } else if !isBreak(nextPhase) && configuration.autoStartFocus {
            let duration = configuration.duration(for: nextPhase)
            let focusEndDate = now.addingTimeInterval(duration)
            newState.status = .running(endDate: focusEndDate)
            newState.startedAt = now
            effects += [
                .scheduleNotification(at: focusEndDate, phase: nextPhase),
                .updateActivity(newState),
                .persist(newState),
            ]
        } else {
            effects += [
                .endActivity,
                .persist(newState),
            ]
        }

        return Transition(state: newState, effects: effects)
    }

    // MARK: - Helpers

    private func computeNextPhase(currentPhase: TimerPhase, cycleIndex: Int) -> TimerPhase {
        switch currentPhase {
        case .focus:
            return cycleIndex >= configuration.cyclesPerRound ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            return .focus
        }
    }

    private func computeNextCycleIndex(currentPhase: TimerPhase, currentCycleIndex: Int) -> Int {
        switch currentPhase {
        case .focus:
            // Setelah longBreak, reset ke 1
            return currentCycleIndex >= configuration.cyclesPerRound ? 1 : currentCycleIndex + 1
        case .shortBreak:
            return currentCycleIndex
        case .longBreak:
            return 1
        }
    }

    private func isBreak(_ phase: TimerPhase) -> Bool {
        phase == .shortBreak || phase == .longBreak
    }

    private func calculateActualSeconds(state: TimerState, now: Date) -> Int {
        guard let startedAt = state.startedAt else { return 0 }
        switch state.status {
        case .running(let endDate):
            let elapsed = min(now, endDate).timeIntervalSince(startedAt)
            return max(0, Int(elapsed))
        case .paused(let remaining):
            let duration = configuration.duration(for: state.phase)
            return max(0, Int(duration - remaining))
        case .idle:
            return 0
        }
    }
}
