import Foundation
import FokusCore

// MARK: - StatsPresentation

public struct DailyStats: Equatable, Sendable {
    public let totalMinutes: Int
    public let sessionCount: Int

    public init(totalMinutes: Int = 0, sessionCount: Int = 0) {
        self.totalMinutes = totalMinutes
        self.sessionCount = sessionCount
    }
}

public struct DayGroup: Identifiable, Equatable, Sendable {
    public let id: Date    // tanggal mulai hari (midnight)
    public let label: String
    public let totalFocusMinutes: Int
    public let sessions: [SessionRecord]
}

public struct WeeklyBar: Identifiable, Equatable, Sendable {
    public let id: Date
    public let dayLabel: String
    public let minutes: Int
    public let isToday: Bool
}

// MARK: - StatsViewModel

@Observable
@MainActor
public final class StatsViewModel {

    private(set) var todayStats: DailyStats = DailyStats()
    private(set) var streak: Int = 0
    private(set) var weeklyTotalMinutes: Int = 0
    private(set) var weeklyBars: [WeeklyBar] = []
    private(set) var dayGroups: [DayGroup] = []
    private(set) var isLoading: Bool = false

    private(set) var currentLocale: Locale = .autoupdatingCurrent

    private let sessions: any SessionRecording
    private var notificationObserver: NSObjectProtocol?

    public init(sessions: any SessionRecording, locale: Locale = .autoupdatingCurrent) {
        self.sessions = sessions
        self.currentLocale = locale
        self.weeklyBars = Self.computeWeeklyBars(from: [], locale: locale)
        observeSessionChanges()
    }

    public func updateLocale(_ locale: Locale) {
        self.currentLocale = locale
        Task { await load() }
    }

    func load() async {
        isLoading = dayGroups.isEmpty && todayStats.sessionCount == 0
        defer { isLoading = false }

        do {
            let all = try await sessions.fetchAll()
            // Statistik fokus dihitung dari sesi fokus yang selesai (BR-03, BR-08)
            let completedFocus = all.filter { $0.outcome == .completed && $0.phase == .focus }

            todayStats = Self.computeToday(from: completedFocus)
            streak = Self.computeStreak(from: completedFocus)
            let bars = Self.computeWeeklyBars(from: completedFocus, locale: currentLocale)
            weeklyBars = bars
            weeklyTotalMinutes = bars.reduce(0) { $0 + $1.minutes }
            dayGroups = Self.groupByDay(records: all, locale: currentLocale)
        } catch {
            // Tetap tampilkan state yang ada jika pembacaan gagal
        }
    }

    func delete(record: SessionRecord) async {
        do {
            try await sessions.delete(id: record.id)
            await load()
        } catch {}
    }

    func deleteAll() async {
        do {
            try await sessions.deleteAll()
            await load()
        } catch {}
    }

    // MARK: - Observation

    private func observeSessionChanges() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .fokusSessionsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.load()
            }
        }
    }

    // MARK: - Computation

    private static func computeToday(from records: [SessionRecord]) -> DailyStats {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todayRecords = records.filter { cal.startOfDay(for: $0.startedAt) == today }
        let totalSecs = todayRecords.reduce(0) { $0 + $1.actualSeconds }
        let minutes = todayRecords.isEmpty ? 0 : max(1, totalSecs / 60)
        return DailyStats(totalMinutes: minutes, sessionCount: todayRecords.count)
    }

    private static func computeStreak(from records: [SessionRecord]) -> Int {
        let cal = Calendar.current
        let days = Set(records.map { cal.startOfDay(for: $0.startedAt) })
        let today = cal.startOfDay(for: Date())

        // BR-08: Hari ini tanpa sesi belum memutus streak sampai hari berakhir
        var currentStreak = 0
        var cursor: Date? = days.contains(today)
            ? today
            : cal.date(byAdding: .day, value: -1, to: today)

        while let checkDay = cursor, days.contains(checkDay) {
            currentStreak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: checkDay)
        }

        return currentStreak
    }

    private static func computeWeeklyBars(from records: [SessionRecord], locale: Locale = .autoupdatingCurrent) -> [WeeklyBar] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEE"

        return (0..<7).reversed().compactMap { offset -> WeeklyBar? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let dayRecords = records.filter { cal.startOfDay(for: $0.startedAt) == day }
            let totalSecs = dayRecords.reduce(0) { $0 + $1.actualSeconds }
            let minutes = dayRecords.isEmpty ? 0 : max(1, totalSecs / 60)
            return WeeklyBar(
                id: day,
                dayLabel: formatter.string(from: day),
                minutes: minutes,
                isToday: offset == 0
            )
        }
    }

    private static func groupByDay(records: [SessionRecord], locale: Locale = .autoupdatingCurrent) -> [DayGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: records) { cal.startOfDay(for: $0.startedAt) }
        return grouped
            .sorted { $0.key > $1.key }
            .map { day, recs in
                let focusSecs = recs
                    .filter { $0.phase == .focus && $0.outcome == .completed }
                    .reduce(0) { $0 + $1.actualSeconds }
                let focusMins = focusSecs > 0 ? max(1, focusSecs / 60) : 0
                return DayGroup(
                    id: day,
                    label: dayLabel(for: day, locale: locale),
                    totalFocusMinutes: focusMins,
                    sessions: recs.sorted { $0.startedAt > $1.startedAt }
                )
            }
    }

    private static func dayLabel(for date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return String(localized: "Hari Ini", locale: locale) }
        if cal.isDateInYesterday(date) { return String(localized: "Kemarin", locale: locale) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
