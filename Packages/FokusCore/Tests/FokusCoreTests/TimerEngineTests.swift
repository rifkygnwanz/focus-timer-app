import Foundation
import FokusCore

// MARK: - TimerEngineTests Placeholder
// Jalankan dengan: swift test --package-path Packages/FokusCore

import Testing

@Suite("TimerEngine — Transisi State")
struct TimerEngineTests {

    let engine = TimerEngine(configuration: .default)
    let now = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Start

    @Test("Idle + start → running dengan endDate yang benar")
    func startFromIdle() {
        let state = TimerState()
        let transition = engine.reduce(state, .start(label: "Belajar"), now: now)

        guard case .running(let endDate) = transition.state.status else {
            Issue.record("Status harus running")
            return
        }
        #expect(abs(endDate.timeIntervalSince(now) - 25 * 60) < 0.001)
        #expect(transition.state.label == "Belajar")
        #expect(transition.effects.contains(.haptic(.light)))
    }

    @Test("Sudah running + start → tidak berubah")
    func startWhenAlreadyRunning() {
        let endDate = now.addingTimeInterval(1000)
        let state = TimerState(status: .running(endDate: endDate))
        let transition = engine.reduce(state, .start(label: nil), now: now)
        #expect(transition.state == state)
    }

    // MARK: - Pause

    @Test("Running + pause → paused dengan sisa waktu yang benar (BR-02)")
    func pauseFromRunning() {
        let endDate = now.addingTimeInterval(1500)
        let state = TimerState(status: .running(endDate: endDate), startedAt: now)
        let transition = engine.reduce(state, .pause, now: now)

        guard case .paused(let remaining) = transition.state.status else {
            Issue.record("Status harus paused")
            return
        }
        #expect(abs(remaining - 1500) < 0.001)
        #expect(transition.effects.contains(.cancelNotifications))
        #expect(transition.effects.contains(.haptic(.light)))
    }

    @Test("Idle + pause → tidak berubah")
    func pauseFromIdle() {
        let state = TimerState()
        let transition = engine.reduce(state, .pause, now: now)
        #expect(transition.state == state)
    }

    // MARK: - Resume

    @Test("Paused + resume → running dengan endDate baru (BR-02)")
    func resumeFromPaused() {
        let state = TimerState(status: .paused(remaining: 800), startedAt: now)
        let transition = engine.reduce(state, .resume, now: now)

        guard case .running(let endDate) = transition.state.status else {
            Issue.record("Status harus running")
            return
        }
        #expect(abs(endDate.timeIntervalSince(now) - 800) < 0.001)
    }

    // MARK: - Stop

    @Test("Running + stop → idle, sesi < 60 detik tidak direkam (BR-04)")
    func stopWithShortSession() {
        let endDate = now.addingTimeInterval(1500)
        let state = TimerState(status: .running(endDate: endDate), startedAt: now.addingTimeInterval(-30))
        let transition = engine.reduce(state, .stop, now: now)

        #expect(transition.state.isIdle)
        let hasRecord = transition.effects.contains(where: {
            if case .record = $0 { return true }
            return false
        })
        #expect(!hasRecord)
    }

    @Test("Running + stop → idle, sesi ≥ 60 detik direkam sebagai cancelled (BR-03)")
    func stopWithLongSession() {
        let endDate = now.addingTimeInterval(1000)
        let startedAt = now.addingTimeInterval(-500)
        let state = TimerState(status: .running(endDate: endDate), startedAt: startedAt)
        let transition = engine.reduce(state, .stop, now: now)

        #expect(transition.state.isIdle)
        let hasRecord = transition.effects.contains(where: {
            if case .record(let r) = $0 { return r.outcome == .cancelled }
            return false
        })
        #expect(hasRecord)
    }

    // MARK: - PhaseElapsed

    @Test("Focus elapsed, cycleIndex < max → pindah ke shortBreak (BR-06 auto-start)")
    func focusElapsedBeforeMax() {
        let config = TimerConfiguration(cyclesPerRound: 4, autoStartBreaks: true)
        let testEngine = TimerEngine(configuration: config)

        let startedAt = now.addingTimeInterval(-1500)
        let endDate = now
        let state = TimerState(
            phase: .focus,
            status: .running(endDate: endDate),
            cycleIndex: 1,
            startedAt: startedAt
        )
        let transition = testEngine.reduce(state, .phaseElapsed, now: now)

        #expect(transition.state.phase == .shortBreak)
        #expect(transition.state.isRunning) // auto-start istirahat
        let hasRecord = transition.effects.contains(where: {
            if case .record(let r) = $0 { return r.outcome == .completed }
            return false
        })
        #expect(hasRecord)
    }

    @Test("Focus elapsed, cycleIndex == max → pindah ke longBreak")
    func focusElapsedAtMax() {
        let config = TimerConfiguration(cyclesPerRound: 4, autoStartBreaks: false)
        let testEngine = TimerEngine(configuration: config)

        let endDate = now
        let state = TimerState(
            phase: .focus,
            status: .running(endDate: endDate),
            cycleIndex: 4,
            startedAt: now.addingTimeInterval(-1500)
        )
        let transition = testEngine.reduce(state, .phaseElapsed, now: now)
        #expect(transition.state.phase == .longBreak)
    }

    @Test("LongBreak elapsed → kembali ke Idle (FR-01)")
    func longBreakElapsedResetsToIdle() {
        let endDate = now
        let state = TimerState(
            phase: .longBreak,
            status: .running(endDate: endDate),
            cycleIndex: 1,
            startedAt: now.addingTimeInterval(-900)
        )
        let transition = engine.reduce(state, .phaseElapsed, now: now)
        #expect(transition.state.isIdle)
        #expect(transition.state.phase == .focus)
        #expect(transition.state.cycleIndex == 1)
    }

    @Test("PhaseElapsed mencatat actualSeconds sesuai durasi fase, tidak terdistorsi waktu jeda")
    func phaseElapsedUsesPlannedSecondsDespitePauseDelay() {
        let startedAt = now.addingTimeInterval(-3600) // sempat dijeda lama
        let state = TimerState(
            phase: .focus,
            status: .running(endDate: now),
            cycleIndex: 1,
            startedAt: startedAt
        )
        let transition = engine.reduce(state, .phaseElapsed, now: now)

        let recordedSeconds = transition.effects.compactMap { effect -> Int? in
            if case .record(let r) = effect { return r.actualSeconds }
            return nil
        }.first

        #expect(recordedSeconds == 25 * 60)
    }

    // MARK: - Skip

    @Test("Skip fokus ≥ 60 detik merekam sesi sebagai cancelled (BR-03/BR-04)")
    func skipFocusAfterOneMinuteRecordsCancelled() {
        let endDate = now.addingTimeInterval(1200)
        let startedAt = now.addingTimeInterval(-300)
        let state = TimerState(
            phase: .focus,
            status: .running(endDate: endDate),
            cycleIndex: 1,
            startedAt: startedAt
        )
        let transition = engine.reduce(state, .skip, now: now)

        #expect(transition.state.phase == .shortBreak)
        let hasCancelledRecord = transition.effects.contains(where: {
            if case .record(let r) = $0 {
                return r.outcome == .cancelled && r.actualSeconds == 300
            }
            return false
        })
        #expect(hasCancelledRecord)
    }
}
