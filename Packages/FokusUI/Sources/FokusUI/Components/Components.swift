import SwiftUI
import FokusCore

// MARK: - ProgressRing

/// Cincin progres generik. Tidak mengenal ViewModel.
public struct ProgressRing: View {
    let progress: Double       // 0...1
    let phase: TimerPhase
    let lineWidth: CGFloat

    public init(progress: Double, phase: TimerPhase, lineWidth: CGFloat = 10) {
        self.progress = progress
        self.phase = phase
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Palette.phaseAccent(for: phase).opacity(0.15), lineWidth: lineWidth)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Palette.phaseAccent(for: phase),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Motion.standard, value: progress)
        }
    }
}

// MARK: - PhaseChip

/// Chip kecil yang menampilkan nama fase dan posisi siklus.
public struct PhaseChip: View {
    let phase: TimerPhase
    let cycleIndex: Int
    let cyclesPerRound: Int

    public init(phase: TimerPhase, cycleIndex: Int, cyclesPerRound: Int) {
        self.phase = phase
        self.cycleIndex = cycleIndex
        self.cyclesPerRound = cyclesPerRound
    }

    private var style: PhaseStyle { PhaseStyle.style(for: phase) }

    private var label: String {
        switch phase {
        case .focus:
            "\(style.name) · \(cycleIndex) dari \(cyclesPerRound)"
        case .shortBreak:
            style.name
        case .longBreak:
            style.name
        }
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: style.symbolName)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(Typography.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(style.color)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(style.color.opacity(0.12), in: Capsule())
    }
}

// MARK: - StatCard

/// Kartu statistik bergaya iOS native (Health / Screen Time) dengan judul, nilai, satuan, dan warna aksen.
public struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let symbolName: String
    let tint: Color

    public init(
        title: String,
        value: String,
        unit: String,
        symbolName: String,
        tint: Color = Palette.accent
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.symbolName = symbolName
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.14), in: Circle())

                Text(title)
                    .font(Typography.statLabel)
                    .foregroundStyle(Palette.secondaryLabel)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(value)
                    .font(Typography.statValue)
                    .foregroundStyle(Palette.label)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Palette.secondaryLabel)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Palette.cardBackground,
            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        )
    }
}

// MARK: - EmptyStateView

/// Tampilan kondisi kosong — ikon + judul + deskripsi.
public struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let description: String

    public init(symbolName: String, title: String, description: String) {
        self.symbolName = symbolName
        self.title = title
        self.description = description
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: symbolName)
                .font(.system(size: 52))
                .foregroundStyle(Palette.accent.opacity(0.6))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.label)
                Text(description)
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - DurationStepperRow

/// Baris pengaturan durasi dengan stepper.
public struct DurationStepperRow: View {
    let label: String
    let unit: String
    let range: ClosedRange<Int>
    let step: Int
    @Binding var value: Int

    public init(
        label: String,
        unit: String = "mnt",
        range: ClosedRange<Int>,
        step: Int = 1,
        value: Binding<Int>
    ) {
        self.label = label
        self.unit = unit
        self.range = range
        self.step = step
        self._value = value
    }

    public var body: some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(Palette.label)

            Spacer()

            HStack(spacing: Spacing.sm) {
                Button {
                    withAnimation(Motion.quick) {
                        value = max(range.lowerBound, value - step)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(value > range.lowerBound ? Palette.accent : Palette.separator)
                        .contentShape(Circle())
                }
                .buttonStyle(.borderless)
                .buttonRepeatBehavior(.enabled)
                .disabled(value <= range.lowerBound)
                .accessibilityLabel("Kurangi \(label)")

                Text("\(value) \(unit)")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.label)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 64)
                    .contentTransition(.numericText())

                Button {
                    withAnimation(Motion.quick) {
                        value = min(range.upperBound, value + step)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(value < range.upperBound ? Palette.accent : Palette.separator)
                        .contentShape(Circle())
                }
                .buttonStyle(.borderless)
                .buttonRepeatBehavior(.enabled)
                .disabled(value >= range.upperBound)
                .accessibilityLabel("Tambah \(label)")
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

// MARK: - Previews

#Preview("ProgressRing") {
    VStack(spacing: Spacing.xl) {
        ProgressRing(progress: 0.65, phase: .focus)
            .frame(width: 200, height: 200)
        ProgressRing(progress: 0.3, phase: .shortBreak)
            .frame(width: 200, height: 200)
        ProgressRing(progress: 0.9, phase: .longBreak)
            .frame(width: 200, height: 200)
    }
    .padding()
}

#Preview("PhaseChip") {
    VStack(spacing: Spacing.md) {
        PhaseChip(phase: .focus, cycleIndex: 2, cyclesPerRound: 4)
        PhaseChip(phase: .shortBreak, cycleIndex: 2, cyclesPerRound: 4)
        PhaseChip(phase: .longBreak, cycleIndex: 4, cyclesPerRound: 4)
    }
    .padding()
}

#Preview("StatCard") {
    HStack {
        StatCard(title: "Hari Ini", value: "75", unit: "mnt", symbolName: "clock.fill")
        StatCard(title: "Streak", value: "7", unit: "hari", symbolName: "flame.fill")
    }
    .padding()
}

#Preview("EmptyStateView") {
    EmptyStateView(
        symbolName: "timer",
        title: "Belum Ada Sesi",
        description: "Mulai sesi pertamamu dan riwayat akan muncul di sini."
    )
}
