import SwiftData
import Foundation
import FokusCore
import OSLog

// MARK: - Notification Name for Session Updates

public extension Notification.Name {
    static let fokusSessionsDidChange = Notification.Name("com.rifkygnwanz.fokus.sessionsDidChange")
}

// MARK: - FocusSessionModel

/// Model SwiftData untuk persistensi sesi lokal. Hanya ada di layer Infrastructure.
@Model
final class FocusSessionModel {
    @Attribute(.unique) var id: UUID
    var phaseRaw: String
    var label: String?
    var startedAt: Date
    var endedAt: Date
    var plannedSeconds: Int
    var actualSeconds: Int
    var outcomeRaw: String
    var cycleIndex: Int

    init(from record: SessionRecord) {
        self.id = record.id
        self.phaseRaw = record.phase.rawValue
        self.label = record.label
        self.startedAt = record.startedAt
        self.endedAt = record.endedAt
        self.plannedSeconds = record.plannedSeconds
        self.actualSeconds = record.actualSeconds
        self.outcomeRaw = record.outcome.rawValue
        self.cycleIndex = record.cycleIndex
    }

    var sessionRecord: SessionRecord {
        SessionRecord(
            id: id,
            phase: TimerPhase(rawValue: phaseRaw) ?? .focus,
            label: label,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedSeconds: plannedSeconds,
            actualSeconds: actualSeconds,
            outcome: SessionOutcome(rawValue: outcomeRaw) ?? .completed,
            cycleIndex: cycleIndex
        )
    }
}

// MARK: - SwiftDataSessionRepository

/// Adapter repositori sesi berbasis SwiftData lokal (di perangkat).
@MainActor
public final class SwiftDataSessionRepository: SessionRecording {

    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.rifkygnwanz.fokus", category: "repository")

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func save(_ record: SessionRecord) async throws {
        let targetID = record.id
        let existingDescriptor = FetchDescriptor<FocusSessionModel>(
            predicate: #Predicate { $0.id == targetID }
        )
        let existing = try modelContext.fetch(existingDescriptor)
        guard existing.isEmpty else {
            logger.debug("Sesi \(record.id) sudah ada, lewati duplikat")
            return
        }

        let model = FocusSessionModel(from: record)
        modelContext.insert(model)
        try modelContext.save()
        logger.debug("Sesi disimpan: \(record.id) (\(record.phase.rawValue), \(record.outcome.rawValue), \(record.actualSeconds)s)")
        NotificationCenter.default.post(name: .fokusSessionsDidChange, object: nil)
    }

    public func fetchAll() async throws -> [SessionRecord] {
        let descriptor = FetchDescriptor<FocusSessionModel>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(\.sessionRecord)
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<FocusSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        let models = try modelContext.fetch(descriptor)
        models.forEach { modelContext.delete($0) }
        try modelContext.save()
        NotificationCenter.default.post(name: .fokusSessionsDidChange, object: nil)
    }

    public func deleteAll() async throws {
        try modelContext.delete(model: FocusSessionModel.self)
        try modelContext.save()
        logger.info("Semua sesi dihapus")
        NotificationCenter.default.post(name: .fokusSessionsDidChange, object: nil)
    }
}
