import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit
import FokusCore
import FokusUI

// MARK: - FokusLiveActivity

struct FokusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FokusActivityAttributes.self) { context in
            LockScreenLiveActivityView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Color(UIColor.secondarySystemBackground))
            .activitySystemActionForegroundColor(Palette.label)
        } dynamicIsland: { context in
            let style = PhaseStyle.style(for: context.state.phase)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: style.symbolName)
                            .foregroundStyle(style.color)
                        Text(phaseCycleText(state: context.state, attributes: context.attributes))
                            .font(Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(style.color)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    timerText(for: context.state)
                        .font(Typography.headline)
                        .monospacedDigit()
                        .foregroundStyle(Palette.label)
                        .frame(width: 72, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.center) {
                    if let label = context.attributes.label, !label.isEmpty {
                        Text(label)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.secondaryLabel)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: Spacing.sm) {
                        if context.state.isRunning {
                            Button(intent: PauseTimerIntent()) {
                                Label("Jeda", systemImage: "pause.fill")
                                    .font(Typography.caption)
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(style.color)
                        } else {
                            Button(intent: ResumeTimerIntent()) {
                                Label("Lanjut", systemImage: "play.fill")
                                    .font(Typography.caption)
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(style.color)
                        }

                        Button(intent: SkipTimerIntent()) {
                            Label("Lewati", systemImage: "forward.fill")
                                .font(Typography.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.secondary)

                        Button(intent: StopTimerIntent()) {
                            Label("Berhenti", systemImage: "stop.fill")
                                .font(Typography.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.red)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } compactLeading: {
                Image(systemName: style.symbolName)
                    .foregroundStyle(style.color)
            } compactTrailing: {
                timerText(for: context.state)
                    .font(Typography.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(style.color)
                    .frame(width: 52, alignment: .trailing)
            } minimal: {
                Image(systemName: style.symbolName)
                    .foregroundStyle(style.color)
            }
        }
    }

    @ViewBuilder
    private func timerText(for state: FokusActivityAttributes.ContentState) -> some View {
        switch state.timing {
        case .running(let start, let end):
            Text(timerInterval: start...end, countsDown: true)
        case .paused(let remaining):
            Text(formatRemaining(remaining))
        }
    }

    private func phaseCycleText(
        state: FokusActivityAttributes.ContentState,
        attributes: FokusActivityAttributes
    ) -> String {
        let style = PhaseStyle.style(for: state.phase)
        if state.phase == .focus {
            return "\(style.name) · \(state.cycleIndex)/\(attributes.cyclesPerRound)"
        }
        return style.name
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - LockScreenLiveActivityView

private struct LockScreenLiveActivityView: View {
    let attributes: FokusActivityAttributes
    let state: FokusActivityAttributes.ContentState

    private var style: PhaseStyle {
        PhaseStyle.style(for: state.phase)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Baris Atas: Chip Fase (kiri) + Badge Status / Label (kanan)
            HStack(alignment: .center, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: style.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                    Text(headerTitle)
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(style.color)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(style.color.opacity(0.15), in: Capsule())

                if let label = attributes.label, !label.isEmpty {
                    Text(label)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.xs)

                statusBadge
            }

            // Baris Tengah: Countdown Timer Besar (kiri) + Tombol Kontrol Bulat (kanan)
            HStack(alignment: .center, spacing: Spacing.md) {
                switch state.timing {
                case .running(let start, let end):
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.label)
                case .paused(let remaining):
                    Text(formatRemaining(remaining))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.label.opacity(0.65))
                }

                Spacer()

                HStack(spacing: Spacing.sm) {
                    if state.isRunning {
                        Button(intent: PauseTimerIntent()) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .tint(style.color)
                        .accessibilityLabel("Jeda")
                    } else {
                        Button(intent: ResumeTimerIntent()) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .tint(style.color)
                        .accessibilityLabel("Lanjut")
                    }

                    Button(intent: SkipTimerIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(Color.secondary.opacity(0.35))
                    .accessibilityLabel("Lewati")

                    Button(intent: StopTimerIntent()) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(Color.red.opacity(0.85))
                    .accessibilityLabel("Berhenti")
                }
            }

            // Baris Bawah: Progress Bar Murni (tanpa teks duplikat) + Info Waktu Mulai & Target Selesai
            VStack(spacing: Spacing.xxs) {
                switch state.timing {
                case .running(let start, let end):
                    ProgressView(
                        timerInterval: start...end,
                        countsDown: true,
                        label: { EmptyView() },
                        currentValueLabel: { EmptyView() }
                    )
                    .tint(style.color)

                    HStack {
                        Text("Mulai \(start.formatted(date: .omitted, time: .shortened))")
                        Spacer()
                        Text("Selesai \(end.formatted(date: .omitted, time: .shortened))")
                    }
                    .font(Typography.caption2)
                    .foregroundStyle(Palette.secondaryLabel)

                case .paused(let remaining):
                    let progress = state.totalDuration > 0
                        ? min(1, max(0, remaining / state.totalDuration))
                        : 0
                    ProgressView(value: progress)
                        .tint(style.color.opacity(0.6))

                    HStack {
                        Text("Timer dijeda")
                        Spacer()
                        Text("Total \(Int(state.totalDuration / 60)) mnt")
                    }
                    .font(Typography.caption2)
                    .foregroundStyle(Palette.secondaryLabel)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if state.isPaused {
            Text("DIJEDA")
                .font(Typography.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(Color.orange.opacity(0.2), in: Capsule())
                .foregroundStyle(.orange)
        } else {
            Text("BERJALAN")
                .font(Typography.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(style.color.opacity(0.15), in: Capsule())
                .foregroundStyle(style.color)
        }
    }

    private var headerTitle: String {
        if state.phase == .focus {
            return "\(style.name) · \(state.cycleIndex)/\(attributes.cyclesPerRound)"
        }
        return style.name
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
