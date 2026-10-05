import SwiftUI
import Charts
import FokusCore
import FokusUI

// MARK: - StatsScreen (Container)

struct StatsScreen: View {
    @State private var viewModel: StatsViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: StatsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        StatsContent(
            viewModel: viewModel,
            onRefresh: {
                await viewModel.load()
            },
            onDelete: { record in
                Task { await viewModel.delete(record: record) }
            }
        )
        .task { await viewModel.load() }
        .onAppear {
            Task { await viewModel.load() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.load() }
            }
        }
    }
}

// MARK: - StatsContent (Presentasi)

struct StatsContent: View {

    let viewModel: StatsViewModel
    let onRefresh: () async -> Void
    let onDelete: (SessionRecord) -> Void

    private var chartMaxY: Int {
        let maxBar = viewModel.weeklyBars.map(\.minutes).max() ?? 0
        return max(30, Int(ceil(Double(maxBar) * 1.25)))
    }

    private var dailyAverageMinutes: Int {
        guard !viewModel.weeklyBars.isEmpty else { return 0 }
        return Int(round(Double(viewModel.weeklyTotalMinutes) / Double(viewModel.weeklyBars.count)))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Kartu ringkasan 2x2 bergaya iOS Health / Reminders
                        summarySection

                        // Grafik 7 hari bergaya iOS Screen Time
                        chartSection

                        // Riwayat sesi per hari
                        historySection
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await onRefresh()
                    }
                }
            }
            .navigationTitle("Statistik")
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    StatCard(
                        title: "Fokus Hari Ini",
                        value: "\(viewModel.todayStats.totalMinutes)",
                        unit: "mnt",
                        symbolName: "timer",
                        tint: Palette.accent
                    )
                    StatCard(
                        title: "Sesi Selesai",
                        value: "\(viewModel.todayStats.sessionCount)",
                        unit: "sesi",
                        symbolName: "checkmark.circle.fill",
                        tint: .green
                    )
                }
                HStack(spacing: Spacing.sm) {
                    StatCard(
                        title: "Streak",
                        value: "\(viewModel.streak)",
                        unit: "hari",
                        symbolName: "flame.fill",
                        tint: .orange
                    )
                    StatCard(
                        title: "7 Hari Terakhir",
                        value: "\(viewModel.weeklyTotalMinutes)",
                        unit: "mnt",
                        symbolName: "chart.bar.fill",
                        tint: Palette.phaseAccent(for: .longBreak)
                    )
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var chartSection: some View {
        Section("Aktivitas 7 Hari Terakhir") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header metrik ala iOS Screen Time
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RATA-RATA HARIAN")
                            .font(Typography.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Palette.secondaryLabel)
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                            Text("\(dailyAverageMinutes)")
                                .font(Typography.headline)
                                .foregroundStyle(Palette.label)
                                .contentTransition(.numericText())
                            Text("mnt / hari")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.secondaryLabel)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TOTAL 7 HARI")
                            .font(Typography.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Palette.secondaryLabel)
                        Text("\(viewModel.weeklyTotalMinutes) mnt")
                            .font(Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Palette.accent)
                            .contentTransition(.numericText())
                    }
                }

                Divider()

                Chart(viewModel.weeklyBars) { bar in
                    BarMark(
                        x: .value("Hari", bar.dayLabel),
                        y: .value("Menit", bar.minutes),
                        width: .ratio(0.56)
                    )
                    .foregroundStyle(
                        bar.isToday
                            ? Palette.accent.gradient
                            : Palette.accent.opacity(0.38).gradient
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .chartYScale(domain: 0...chartMaxY)
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Palette.separator.opacity(0.6))
                        if let mins = value.as(Int.self) {
                            AxisValueLabel("\(mins)m")
                                .font(Typography.caption2)
                                .foregroundStyle(Palette.secondaryLabel)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(Typography.caption2)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if viewModel.dayGroups.isEmpty {
            Section("Riwayat Sesi") {
                EmptyStateView(
                    symbolName: "clock.badge.checkmark",
                    title: "Belum Ada Riwayat Sesi",
                    description: "Selesaikan atau jalankan sesi fokus minimal 1 menit untuk melihat riwayat aktivitasmu di sini."
                )
            }
        } else {
            ForEach(viewModel.dayGroups) { group in
                Section {
                    ForEach(group.sessions) { record in
                        SessionRow(record: record)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(record)
                                } label: {
                                    Label("Hapus", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(group.label)
                        Spacer()
                        if group.totalFocusMinutes > 0 {
                            Text("\(group.totalFocusMinutes) mnt fokus")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.secondaryLabel)
                                .textCase(nil)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - SessionRow

private struct SessionRow: View {
    let record: SessionRecord

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private var phaseStyle: PhaseStyle {
        PhaseStyle.style(for: record.phase)
    }

    private var trimmedLabel: String? {
        guard let raw = record.label?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }

    var body: some View {
        let start = Self.timeFormatter.string(from: record.startedAt)
        let end = Self.timeFormatter.string(from: record.endedAt)

        HStack(spacing: Spacing.md) {
            // Ikon fase bergaya iOS Settings / Health (rounded square)
            Image(systemName: phaseStyle.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(phaseStyle.color)
                .frame(width: 32, height: 32)
                .background(
                    phaseStyle.color.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                if let trimmed = trimmedLabel {
                    Text(verbatim: trimmed)
                        .font(Typography.body)
                        .foregroundStyle(Palette.label)
                        .lineLimit(1)

                    (Text(phaseStyle.titleKey) + Text(" • \(start) – \(end)"))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                } else {
                    Text(phaseStyle.titleKey)
                        .font(Typography.body)
                        .foregroundStyle(Palette.label)
                        .lineLimit(1)

                    Text(verbatim: "\(start) – \(end)")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if record.actualSeconds >= 60 {
                    Text("\(record.actualSeconds / 60) mnt")
                        .font(Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.label)
                } else {
                    Text("\(max(1, record.actualSeconds)) dtk")
                        .font(Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.label)
                }

                HStack(spacing: Spacing.xxs) {
                    Image(systemName: record.outcome == .completed ? "checkmark.circle.fill" : "minus.circle.fill")
                        .font(.system(size: 11))
                    if record.outcome == .completed {
                        Text("Selesai")
                            .font(Typography.caption2)
                    } else {
                        Text("Dihentikan")
                            .font(Typography.caption2)
                    }
                }
                .foregroundStyle(record.outcome == .completed ? .green : Palette.secondaryLabel)
            }
        }
        .padding(.vertical, 2)
    }
}

