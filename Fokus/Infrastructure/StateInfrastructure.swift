import Foundation
import FokusCore

// MARK: - SystemClock

/// Implementasi Clock yang menggunakan jam sistem.
public final class SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

// MARK: - AppGroupStateStore

/// Menyimpan dan memuat TimerState serta antrean SessionRecord dari App Group UserDefaults.
/// Memungkinkan pemulihan state (FR-10) dan sinkronisasi penuh dengan Live Activity extension.
public final class AppGroupStateStore: TimerStateStoring {

    nonisolated(unsafe) private let defaults: UserDefaults
    private let key = "fokus.timerState"
    private let pendingRecordsKey = "fokus.pendingSessionRecords"

    public nonisolated init(suiteName: String = "group.com.rifkygnwanz.fokus") {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    public func save(_ state: TimerState) throws {
        let data = try JSONEncoder().encode(state)
        defaults.set(data, forKey: key)
    }

    public func load() throws -> TimerState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(TimerState.self, from: data)
    }

    /// Menyimpan rekaman sesi sementara saat dipicu dari Live Activity / Notification Intent
    /// agar dapat dimasukkan ke SwiftData oleh aplikasi utama.
    public func enqueuePendingRecord(_ record: SessionRecord) {
        var current = loadPendingRecords()
        if !current.contains(where: { $0.id == record.id }) {
            current.append(record)
        }
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: pendingRecordsKey)
        }
    }

    /// Mengambil dan mengosongkan antrean rekaman sesi yang tertunda.
    public func drainPendingRecords() -> [SessionRecord] {
        let records = loadPendingRecords()
        if !records.isEmpty {
            defaults.removeObject(forKey: pendingRecordsKey)
        }
        return records
    }

    private func loadPendingRecords() -> [SessionRecord] {
        guard let data = defaults.data(forKey: pendingRecordsKey),
              let records = try? JSONDecoder().decode([SessionRecord].self, from: data) else {
            return []
        }
        return records
    }
}
