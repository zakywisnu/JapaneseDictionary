import Foundation
import SwiftData

public final class StandardLearningPathRepository {
    private let store: StudyStore
    private let saveContext: (ModelContext) throws -> Void
    public init(store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) { self.store = store; saveContext = save }
    public func allProgress() throws -> [LearningPathProgress] {
        try store.makeContext().fetch(FetchDescriptor<LearningPathProgressModel>()).map { try $0.value() }.sorted { $0.pathID < $1.pathID }
    }
    public func progress(pathID: String) throws -> LearningPathProgress? { try allProgress().first { $0.pathID == pathID } }
    public func save(_ value: LearningPathProgress, steps: [LearningPathStep]) throws {
        try LearningPathValidator.validate(value, steps: steps)
        try transaction { context in try upsert(value, context: context) }
    }
    public func complete(step: LearningPathStep, steps: [LearningPathStep], pathID: String, now: Date) throws -> LearningPathProgress {
        try update(stepID: step.id, steps: steps, pathID: pathID, now: now) { value, context in
            guard steps.contains(step) else { throw LearningPathError.invalidProgress }
            let attempts = try context.fetch(FetchDescriptor<ExerciseAttemptModel>()).map { try $0.value() }
            guard LearningStepCompletionPolicy().isComplete(step: step, attempts: attempts) else { throw LearningPathError.incompleteActivity }
            if !value.isComplete(step) { value.completedRevisions.append(.init(stepID: step.id, revision: step.revision, completedAt: now)) }
            value.skippedSteps.removeAll { $0.stepID == step.id }
            value.currentStepID = nextStep(value, steps: steps)
        }
    }
    static func completeInContext(_ context: ModelContext, step: LearningPathStep, steps: [LearningPathStep], pathID: String, now: Date) throws {
        try LearningPathValidator.validateSteps(steps)
        guard steps.contains(step) else { throw LearningPathError.invalidProgress }
        let attempts = try context.fetch(FetchDescriptor<ExerciseAttemptModel>()).map { try $0.value() }
        guard LearningStepCompletionPolicy().isComplete(step: step, attempts: attempts) else { return }
        let models = try context.fetch(FetchDescriptor<LearningPathProgressModel>())
        let model = models.first { $0.pathID == pathID }
        var value = try model?.value() ?? LearningPathProgress(pathID: pathID, currentStepID: step.id, updatedAt: now)
        if !value.isComplete(step) { value.completedRevisions.append(.init(stepID: step.id, revision: step.revision, completedAt: now)) }
        value.skippedSteps.removeAll { $0.stepID == step.id }
        value.currentStepID = steps.first { !value.isComplete($0) && !value.skippedStepIDs.contains($0.id) }?.id
        value.updatedAt = now
        try LearningPathValidator.validate(value, steps: steps)
        if let model { try model.apply(value) }
        else { guard models.count < 100 else { throw LearningPathError.invalidProgress }; context.insert(try LearningPathProgressModel(value: value)) }
    }
    public func skip(stepID: String, steps: [LearningPathStep], pathID: String, now: Date) throws -> LearningPathProgress {
        try update(stepID: stepID, steps: steps, pathID: pathID, now: now) { value, _ in
            if !value.skippedStepIDs.contains(stepID) { value.skippedSteps.append(.init(stepID: stepID, skippedAt: now)) }
            value.currentStepID = nextStep(value, steps: steps)
        }
    }
    public func revisit(stepID: String, steps: [LearningPathStep], pathID: String, now: Date) throws -> LearningPathProgress {
        try update(stepID: stepID, steps: steps, pathID: pathID, now: now) { value, _ in
            value.skippedSteps.removeAll { $0.stepID == stepID }; value.currentStepID = stepID
        }
    }
    private func nextStep(_ value: LearningPathProgress, steps: [LearningPathStep]) -> String? {
        steps.first { !value.isComplete($0) && !value.skippedStepIDs.contains($0.id) }?.id
    }
    private func update(stepID: String, steps: [LearningPathStep], pathID: String, now: Date, change: (inout LearningPathProgress, ModelContext) throws -> Void) throws -> LearningPathProgress {
        try LearningPathValidator.validateSteps(steps)
        guard steps.contains(where: { $0.id == stepID }) else { throw LearningPathError.invalidProgress }
        return try transaction { context in
            var value = try context.fetch(FetchDescriptor<LearningPathProgressModel>()).first(where: { $0.pathID == pathID })?.value() ?? .init(pathID: pathID, currentStepID: steps.first?.id, updatedAt: now)
            try change(&value, context); value.updatedAt = now
            try LearningPathValidator.validate(value, steps: steps)
            try upsert(value, context: context); return value
        }
    }
    private func upsert(_ value: LearningPathProgress, context: ModelContext) throws {
        let models = try context.fetch(FetchDescriptor<LearningPathProgressModel>())
        if let model = models.first(where: { $0.pathID == value.pathID }) { try model.apply(value) }
        else { guard models.count < 100 else { throw LearningPathError.invalidProgress }; context.insert(try LearningPathProgressModel(value: value)) }
    }
    private func transaction<T>(_ operation: (ModelContext) throws -> T) throws -> T {
        let context = store.makeContext()
        do { let result = try operation(context); try saveContext(context); store.refreshContext(); return result }
        catch { context.rollback(); throw error }
    }
}
