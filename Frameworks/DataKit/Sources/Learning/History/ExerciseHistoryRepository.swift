import Foundation
import SwiftData

public final class StandardExerciseHistoryRepository {
    private let store: StudyStore
    private let saveContext: (ModelContext) throws -> Void
    public init(store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) { self.store = store; saveContext = save }
    public func attempts() throws -> [ExerciseAttempt] {
        try store.makeContext().fetch(FetchDescriptor<ExerciseAttemptModel>()).map { try $0.value() }.sorted { $0.submittedAt == $1.submittedAt ? $0.id.uuidString < $1.id.uuidString : $0.submittedAt < $1.submittedAt }
    }
    public func checkpoints() throws -> [ExerciseCheckpoint] {
        try store.makeContext().fetch(FetchDescriptor<ExerciseCheckpointModel>()).map { try $0.value() }.sorted { $0.activityKey < $1.activityKey }
    }
    public func checkpoint(activityKey: String) throws -> ExerciseCheckpoint? { try checkpoints().first { $0.activityKey == activityKey } }
    public func record(_ attempt: ExerciseAttempt, checkpoint: ExerciseCheckpoint) throws {
        try ExerciseHistoryValidator.validateAttempt(attempt)
        guard checkpoint.revealedAttemptID == attempt.id, checkpoint.sessionID == attempt.sessionID else { throw ExerciseHistoryError.invalidRecord }
        try transaction { context in
            let models = try context.fetch(FetchDescriptor<ExerciseAttemptModel>())
            var attempts = try models.map { try $0.value() }
            if let existing = attempts.first(where: { $0.id == attempt.id }) {
                guard existing == attempt else { throw ExerciseHistoryError.conflictingID }
                try ExerciseHistoryValidator.validateCheckpoint(checkpoint, attempts: attempts)
                // Retried submissions must not move a session backwards after Next has succeeded.
                return
            }
            attempts.append(attempt)
            try ExerciseHistoryValidator.validateCheckpoint(checkpoint, attempts: attempts)
            if attempts.count > 10_000 {
                let checkpoints = try context.fetch(FetchDescriptor<ExerciseCheckpointModel>()).map { try $0.value() }
                let protectedSessions = Set(checkpoints.map(\.sessionID) + [checkpoint.sessionID])
                let removable = attempts.filter { !protectedSessions.contains($0.sessionID) }.sorted {
                    $0.submittedAt == $1.submittedAt ? $0.id.uuidString < $1.id.uuidString : $0.submittedAt < $1.submittedAt
                }
                let excess = attempts.count - 10_000
                guard removable.count >= excess else { throw ExerciseHistoryError.historyFull }
                let removedIDs = Set(removable.prefix(excess).map(\.id))
                for model in models where removedIDs.contains(model.id) { context.delete(model) }
            }
            context.insert(try ExerciseAttemptModel(value: attempt))
            try upsert(checkpoint, context: context)
        }
    }
    public func saveCheckpoint(_ checkpoint: ExerciseCheckpoint) throws {
        try transaction { context in
            let attempts = try context.fetch(FetchDescriptor<ExerciseAttemptModel>()).map { try $0.value() }
            try ExerciseHistoryValidator.validateCheckpoint(checkpoint, attempts: attempts)
            try upsert(checkpoint, context: context)
        }
    }
    public func deleteCheckpoint(activityKey: String) throws {
        try transaction { context in
            for model in try context.fetch(FetchDescriptor<ExerciseCheckpointModel>()) where model.activityKey == activityKey { context.delete(model) }
        }
    }
    public func finish(activityKey: String, sessionID: UUID) throws {
        try transaction { context in
            for model in try context.fetch(FetchDescriptor<ExerciseCheckpointModel>()) where model.activityKey == activityKey {
                guard try model.value().sessionID == sessionID else { throw ExerciseHistoryError.invalidRecord }
                context.delete(model)
            }
        }
    }
    public func finishPath(activityKey: String, sessionID: UUID, step: LearningPathStep, steps: [LearningPathStep], pathID: String, now: Date) throws {
        guard step.activityKey == activityKey else { throw LearningPathError.invalidProgress }
        try transaction { context in
            for model in try context.fetch(FetchDescriptor<ExerciseCheckpointModel>()) where model.activityKey == activityKey {
                guard try model.value().sessionID == sessionID else { throw ExerciseHistoryError.invalidRecord }
                context.delete(model)
            }
            try StandardLearningPathRepository.completeInContext(context, step: step, steps: steps, pathID: pathID, now: now)
        }
    }
    private func upsert(_ checkpoint: ExerciseCheckpoint, context: ModelContext) throws {
        let models = try context.fetch(FetchDescriptor<ExerciseCheckpointModel>())
        if let model = models.first(where: { $0.activityKey == checkpoint.activityKey }) { try model.apply(checkpoint) }
        else { guard models.count < 100 else { throw ExerciseHistoryError.invalidRecord }; context.insert(try ExerciseCheckpointModel(value: checkpoint)) }
    }
    private func transaction(_ operation: (ModelContext) throws -> Void) throws {
        let context = store.makeContext()
        do { try operation(context); try saveContext(context); store.refreshContext() }
        catch { context.rollback(); throw error }
    }
}
