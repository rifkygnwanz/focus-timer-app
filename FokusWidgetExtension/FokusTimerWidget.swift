import AppIntents
import SwiftUI
import WidgetKit
import FokusCore
import FokusUI

// MARK: - Timeline Entry

struct TimerWidgetEntry: TimelineEntry {
    let date: Date
    let state: TimerState
    let configuration: TimerConfiguration
}

// MARK: - Timeline Provider

struct TimerWidgetProvider: TimelineProvider {
    typealias Entry = TimerWidgetEntry

    func placeholder(in context: Context) -> TimerWidgetEntry {
        TimerWidgetEntry(
            date: Date(),
            state: TimerState(
                phase: .focus,
                status: .running(endDate: Date().addingTimeInterval(25 * 60)),
                cycleIndex: 1
            ),
            configuration: TimerConfiguration.default
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerWidgetEntry) -> Void) {
        let entry = currentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let entries: [TimerWidgetEntry] = [entry]
        var reloadPolicy: TimelineReloadPolicy = .never

        if case .running(let endDate) = entry.state.status {
            if endDate > Date() {
                reloadPolicy = .after(endDate)
            } else {
                reloadPolicy = .atEnd
            }
        }

        let timeline = Timeline(entries: entries, policy: reloadPolicy)
        completion(timeline)
    }

    private func currentEntry() -> TimerWidgetEntry {
        let store = AppGroupStateStore(suiteName: TimerExternalSync.appGroupSuiteName)
        var state = (try? store.load()) ?? TimerState()
        let config = loadConfiguration()

        // Jika fase sudah lewat saat widget di-refresh, rekonsiliasi sekilas agar waktu tidak negatif
        if case .running(let endDate) = state.status, Date() >= endDate {
            let engine = TimerEngine(configuration: config)
            let transition = engine.reduce(state, .phaseElapsed, now: endDate)
            state = transition.state
            try? store.save(state)
            for effect in transition.effects {
                if case .record(let record) = effect {
                    store.enqueuePendingRecord(record)
                }
            }
        }

        return TimerWidgetEntry(date: Date(), state: state, configuration: config)
    }

    private func loadConfiguration() -> TimerConfiguration {
        let defaults = UserDefaults(suiteName: TimerExternalSync.appGroupSuiteName) ?? .standard
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

// MARK: - Widget View Coordinator

struct FokusTimerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TimerWidgetProvider.Entry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallTimerWidgetView(entry: entry)
            case .systemMedium:
                MediumTimerWidgetView(entry: entry)
            default:
                SmallTimerWidgetView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            Color(UIColor.secondarySystemBackground)
        }
    }
}

// MARK: - Small Widget (.systemSmall)

private struct SmallTimerWidgetView: View {
    let entry: TimerWidgetEntry

    private var style: PhaseStyle {
        PhaseStyle.style(for: entry.state.phase)
    }

    private var totalDuration: TimeInterval {
        entry.configuration.duration(for: entry.state.phase)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Icon + Phase Name + Badge/Cycle
            HStack(spacing: Spacing.xs) {
                Image(systemName: style.symbolName)
                    .foregroundStyle(style.color)
                    .font(.system(size: 13, weight: .semibold))

                Text(style.titleKey)
                    .font(Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.label)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if entry.state.isPaused {
                    Text("DIJEDA")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18), in: Capsule())
                } else if entry.state.isRunning {
                    Text("\(entry.state.cycleIndex)/\(entry.configuration.cyclesPerRound)")
                        .font(Typography.caption2)
                        .foregroundStyle(Palette.secondaryLabel)
                } else {
                    Text("\(entry.configuration.focusMinutes)m")
                        .font(Typography.caption2)
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }

            Spacer(minLength: 4)

            // Center: Main Timer Display
            VStack(alignment: .leading, spacing: 2) {
                timerDisplay
                    .frame(maxWidth: .infinity, alignment: .leading)

                subtitleView
            }

            Spacer(minLength: 6)

            // Bottom: Interactive Control Buttons
            actionButtons
        }
    }

    @ViewBuilder
    private var timerDisplay: some View {
        switch entry.state.status {
        case .running(let endDate):
            Text(timerInterval: Date()...endDate, countsDown: true)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.label)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        case .paused(let remaining):
            Text(formatRemaining(remaining))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.label)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        case .idle:
            Text(formatRemaining(totalDuration))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.label)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var subtitleView: some View {
        switch entry.state.status {
        case .running(let endDate):
            Text("Selesai \(endDate.formatted(date: .omitted, time: .shortened))")
                .font(Typography.caption2)
                .foregroundStyle(Palette.secondaryLabel)
        case .paused:
            Text("Timer dijeda")
                .font(Typography.caption2)
                .foregroundStyle(.orange)
        case .idle:
            Text("Siap fokus")
                .font(Typography.caption2)
                .foregroundStyle(Palette.secondaryLabel)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch entry.state.status {
        case .idle:
            Button(intent: StartTimerIntent()) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "play.fill")
                    Text("Mulai")
                }
                .font(Typography.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(style.color)

        case .running:
            HStack(spacing: Spacing.xs) {
                Button(intent: PauseTimerIntent()) {
                    Image(systemName: "pause.fill")
                        .font(Typography.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(style.color)

                Button(intent: SkipTimerIntent()) {
                    Image(systemName: "forward.fill")
                        .font(Typography.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .tint(Palette.secondaryLabel)
            }

        case .paused:
            HStack(spacing: Spacing.xs) {
                Button(intent: ResumeTimerIntent()) {
                    Image(systemName: "play.fill")
                        .font(Typography.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(style.color)

                Button(intent: StopTimerIntent()) {
                    Image(systemName: "stop.fill")
                        .font(Typography.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Medium Widget (.systemMedium)

private struct MediumTimerWidgetView: View {
    let entry: TimerWidgetEntry

    private var style: PhaseStyle {
        PhaseStyle.style(for: entry.state.phase)
    }

    private var totalDuration: TimeInterval {
        entry.configuration.duration(for: entry.state.phase)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Kolom Kiri: Informasi Status & Countdown
            VStack(alignment: .leading, spacing: 0) {
                // Header Fase & Siklus
                HStack(spacing: Spacing.xs) {
                    Image(systemName: style.symbolName)
                        .foregroundStyle(style.color)
                        .font(.system(size: 13, weight: .semibold))

                    Text(style.titleKey)
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.label)

                    Text("· \(entry.state.cycleIndex)/\(entry.configuration.cyclesPerRound)")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)

                    Spacer(minLength: 0)

                    if entry.state.isPaused {
                        Text("DIJEDA")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.18), in: Capsule())
                    }
                }

                Spacer(minLength: 2)

                // Timer Besar
                timerDisplay
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Subtitle
                subtitleView

                Spacer(minLength: 4)

                // Bar Progres
                progressBar
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider Pemisah
            Divider()
                .padding(.vertical, Spacing.xs)

            // Kolom Kanan: Tombol Aksi Interaktif
            VStack(spacing: Spacing.xs) {
                actionButtons
            }
            .frame(width: 120)
        }
    }

    @ViewBuilder
    private var timerDisplay: some View {
        switch entry.state.status {
        case .running(let endDate):
            Text(timerInterval: Date()...endDate, countsDown: true)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.label)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        case .paused(let remaining):
            Text(formatRemaining(remaining))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.label)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        case .idle:
            Text(formatRemaining(totalDuration))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.label)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var subtitleView: some View {
        if let label = entry.state.label, !label.isEmpty {
            Text(verbatim: label)
                .font(Typography.caption2)
                .foregroundStyle(Palette.secondaryLabel)
                .lineLimit(1)
        } else {
            switch entry.state.status {
            case .running(let endDate):
                Text("Selesai pukul \(endDate.formatted(date: .omitted, time: .shortened))")
                    .font(Typography.caption2)
                    .foregroundStyle(Palette.secondaryLabel)
            case .paused:
                Text("Timer sedang dijeda")
                    .font(Typography.caption2)
                    .foregroundStyle(.orange)
            case .idle:
                Text("Sesi \(entry.configuration.focusMinutes) menit")
                    .font(Typography.caption2)
                    .foregroundStyle(Palette.secondaryLabel)
            }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        switch entry.state.status {
        case .running(let endDate):
            let start = entry.state.startedAt ?? endDate.addingTimeInterval(-totalDuration)
            ProgressView(timerInterval: start...endDate, countsDown: false)
                .tint(style.color)
        case .paused(let remaining):
            let progress = totalDuration > 0
                ? min(1.0, max(0.0, 1.0 - (remaining / totalDuration)))
                : 0.0
            ProgressView(value: progress)
                .tint(style.color.opacity(0.6))
        case .idle:
            ProgressView(value: 0.0)
                .tint(style.color.opacity(0.3))
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch entry.state.status {
        case .idle:
            Button(intent: StartTimerIntent()) {
                VStack(spacing: Spacing.xxs) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Mulai Fokus")
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(style.color)

        case .running:
            Button(intent: PauseTimerIntent()) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "pause.fill")
                    Text("Jeda")
                }
                .font(Typography.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(style.color)

            HStack(spacing: Spacing.xs) {
                Button(intent: SkipTimerIntent()) {
                    Image(systemName: "forward.fill")
                        .font(Typography.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(.bordered)
                .tint(Palette.secondaryLabel)

                Button(intent: StopTimerIntent()) {
                    Image(systemName: "stop.fill")
                        .font(Typography.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

        case .paused:
            Button(intent: ResumeTimerIntent()) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "play.fill")
                    Text("Lanjut")
                }
                .font(Typography.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(style.color)

            HStack(spacing: Spacing.xs) {
                Button(intent: SkipTimerIntent()) {
                    Image(systemName: "forward.fill")
                        .font(Typography.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(.bordered)
                .tint(Palette.secondaryLabel)

                Button(intent: StopTimerIntent()) {
                    Image(systemName: "stop.fill")
                        .font(Typography.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Widget Definition

public struct FokusTimerWidget: Widget {
    public let kind: String = "FokusTimerWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerWidgetProvider()) { entry in
            FokusTimerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Timer Fokus")
        .description("Kontrol dan pantau timer Fokus langsung dari Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
