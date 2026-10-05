import Foundation

// MARK: - Clock

/// Protokol jam yang bisa diganti dengan fake saat pengujian.
/// Jangan pernah memanggil `Date()` langsung di dalam logika — gunakan `clock.now` (S3).
public protocol Clock: Sendable {
    var now: Date { get }
}

// MARK: - NotificationScheduling

/// Kemampuan menjadwalkan dan membatalkan notifikasi lokal.
public protocol NotificationScheduling: Sendable {
    func scheduleEndOfPhase(at date: Date, phase: TimerPhase) async throws
    func cancelPending() async
}

// MARK: - ActivityPresenting

/// Kemampuan mengelola Live Activity.
public protocol ActivityPresenting: Sendable {
    func startActivity(state: TimerState, configuration: TimerConfiguration) async
    func updateActivity(state: TimerState) async
    func endActivity() async
}

// MARK: - SessionRecording

/// Kemampuan menyimpan rekaman sesi ke penyimpanan persisten.
public protocol SessionRecording: Sendable {
    func save(_ record: SessionRecord) async throws
    func fetchAll() async throws -> [SessionRecord]
    func delete(id: UUID) async throws
    func deleteAll() async throws
}

// MARK: - TimerStateStoring

/// Kemampuan menyimpan state timer ke App Group (untuk pemulihan dan Live Activity extension).
public protocol TimerStateStoring: Sendable {
    func save(_ state: TimerState) throws
    func load() throws -> TimerState?
}

// MARK: - HapticFeedbackProviding

/// Kemampuan menghasilkan haptic feedback.
public protocol HapticFeedbackProviding: Sendable {
    func trigger(_ event: HapticEvent)
}
