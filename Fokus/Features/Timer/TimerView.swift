import SwiftUI
import FokusCore
import FokusUI

// MARK: - TimerScreen (Container — "Pintar")

/// Layar timer — memegang ViewModel dan dependensi.
/// Tidak bisa dipratinjau langsung; gunakan TimerContent untuk preview.
struct TimerScreen: View {

    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: TimerViewModel

    init(viewModel: TimerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        TimerContent(
            state: viewModel.presentation,
            actions: viewModel.actions
        )
        .task {
            await viewModel.reconcile()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await viewModel.reconcile()
                }
            }
        }
    }
}

// MARK: - TimerContent (Presentasi — "Bodoh")

/// Tampilan murni. Hanya menerima data dan closure. Bisa dipratinjau tanpa dependensi.
struct TimerContent: View {

    let state: TimerPresentation
    let actions: TimerActions

    @State private var labelInput: String = ""
    @State private var showStopAlert: Bool = false

    var body: some View {
        ZStack {
            // Background gradient halus sesuai fase
            phaseBackground
                .ignoresSafeArea()
                .animation(Motion.slow, value: state.phase)

            VStack(spacing: 0) {
                Spacer()

                // Chip fase
                PhaseChip(
                    phase: state.phase,
                    cycleIndex: state.cycleIndex,
                    cyclesPerRound: state.cyclesPerRound
                )
                .animation(Motion.standard, value: state.phase)

                Spacer().frame(height: Spacing.xl)

                // Cincin timer
                timerRing

                Spacer().frame(height: Spacing.xl)

                // Input label (hanya saat idle)
                if state.isIdle {
                    labelField
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Kontrol
                controlButtons

                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .alert("Berhentikan Timer?", isPresented: $showStopAlert) {
            Button("Berhenti", role: .destructive) { actions.onStop() }
            Button("Batalkan", role: .cancel) {}
        } message: {
            Text("Progres sesi saat ini akan dibatalkan.")
        }
    }

    // MARK: - Subviews

    private var phaseBackground: some View {
        LinearGradient(
            colors: [
                Color(UIColor.systemBackground),
                PhaseStyle.style(for: state.phase).color.opacity(0.08),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var timerRing: some View {
        ZStack {
            ProgressRing(progress: state.progress, phase: state.phase, lineWidth: 12)
                .frame(width: 240, height: 240)

            VStack(spacing: Spacing.xs) {
                timerDisplay
                    .animation(Motion.standard, value: state.isRunning)

                if let label = state.label, !label.isEmpty {
                    Text(verbatim: label)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var timerDisplay: some View {
        if state.isRunning, let endDate = state.endDate {
            // Hemat baterai: sistem yang hitung mundur (9.1)
            Text(timerInterval: Date.now...endDate, countsDown: true)
                .font(Typography.timerLarge)
                .foregroundStyle(Palette.label)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(countsDown: true))
        } else {
            // Idle atau paused — tampilkan nilai statis
            Text(formattedRemaining(state.remainingSeconds))
                .font(Typography.timerLarge)
                .foregroundStyle(state.isPaused ? Palette.label.opacity(0.6) : Palette.label)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(countsDown: true))
        }
    }

    private var labelField: some View {
        TextField("Label sesi (opsional)", text: $labelInput)
            .font(Typography.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.label)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .background(Palette.secondaryBackground, in: RoundedRectangle(cornerRadius: Radius.md))
            .frame(maxWidth: 280)
            .submitLabel(.done)
    }

    private var controlButtons: some View {
        VStack(spacing: Spacing.md) {
            // Tombol utama
            if state.isIdle {
                Button("Mulai") {
                    let label = labelInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    actions.onStart(label.isEmpty ? nil : label)
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if state.isRunning {
                Button("Jeda") { actions.onPause() }
                    .buttonStyle(PrimaryButtonStyle())
            } else if state.isPaused {
                Button("Lanjut") { actions.onResume() }
                    .buttonStyle(PrimaryButtonStyle())
            }

            // Tombol sekunder (hanya saat aktif)
            if !state.isIdle {
                HStack(spacing: Spacing.xl) {
                    Button {
                        showStopAlert = true
                    } label: {
                        Label("Berhenti", systemImage: "stop.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        actions.onSkip()
                    } label: {
                        Label("Lewati", systemImage: "forward.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(Motion.spring, value: state.isIdle)
    }

    // MARK: - Helpers

    private func formattedRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Previews

#Preview("Timer — Idle") {
    TimerContent(
        state: TimerPresentation(
            phase: .focus,
            cycleIndex: 1,
            cyclesPerRound: 4,
            statusLabel: "",
            progress: 1.0,
            endDate: nil,
            remainingSeconds: 25 * 60,
            isRunning: false,
            isPaused: false,
            isIdle: true,
            label: nil
        ),
        actions: TimerActions(
            onStart: { _ in },
            onPause: {},
            onResume: {},
            onStop: {},
            onSkip: {}
        )
    )
}

#Preview("Timer — Berjalan") {
    TimerContent(
        state: TimerPresentation(
            phase: .focus,
            cycleIndex: 2,
            cyclesPerRound: 4,
            statusLabel: "",
            progress: 0.65,
            endDate: Date.now.addingTimeInterval(875),
            remainingSeconds: 875,
            isRunning: true,
            isPaused: false,
            isIdle: false,
            label: "Belajar Swift"
        ),
        actions: TimerActions(
            onStart: { _ in },
            onPause: {},
            onResume: {},
            onStop: {},
            onSkip: {}
        )
    )
}

#Preview("Timer — Istirahat Pendek") {
    TimerContent(
        state: TimerPresentation(
            phase: .shortBreak,
            cycleIndex: 2,
            cyclesPerRound: 4,
            statusLabel: "",
            progress: 0.4,
            endDate: Date.now.addingTimeInterval(180),
            remainingSeconds: 180,
            isRunning: true,
            isPaused: false,
            isIdle: false,
            label: nil
        ),
        actions: TimerActions(
            onStart: { _ in },
            onPause: {},
            onResume: {},
            onStop: {},
            onSkip: {}
        )
    )
}
