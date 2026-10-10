import Foundation
import SwiftData

public struct LearningPathStep: Codable, Equatable, Identifiable {
    public var id: String
    public var revision: Int
    public var title: String
    public var activityKey: String
    public var requiredContentIDs: [String]
    public init(id: String, revision: Int, title: String, activityKey: String, requiredContentIDs: [String]) {
        self.id = id; self.revision = revision; self.title = title; self.activityKey = activityKey; self.requiredContentIDs = requiredContentIDs
    }
}
public struct LearningPathRevision: Codable, Equatable {
    public var stepID: String
    public var revision: Int
    public var completedAt: Date
    public init(stepID: String, revision: Int, completedAt: Date) { self.stepID = stepID; self.revision = revision; self.completedAt = completedAt }
}
public struct LearningPathSkip: Codable, Equatable {
    public var stepID: String
    public var skippedAt: Date
    public init(stepID: String, skippedAt: Date) { self.stepID = stepID; self.skippedAt = skippedAt }
}
public struct LearningPathProgress: Codable, Equatable {
    public var pathID: String
    public var currentStepID: String?
    public var completedRevisions: [LearningPathRevision]
    public var skippedSteps: [LearningPathSkip]
    public var updatedAt: Date
    public var skippedStepIDs: [String] { skippedSteps.map(\.stepID) }
    public init(pathID: String, currentStepID: String?, completedRevisions: [LearningPathRevision] = [], skippedSteps: [LearningPathSkip] = [], updatedAt: Date) {
        self.pathID = pathID; self.currentStepID = currentStepID; self.completedRevisions = completedRevisions; self.skippedSteps = skippedSteps; self.updatedAt = updatedAt
    }
    public func isComplete(_ step: LearningPathStep) -> Bool { completedRevisions.contains { $0.stepID == step.id && $0.revision == step.revision } }
}
@Model public final class LearningPathProgressModel {
    @Attribute(.unique) public var pathID: String
    public var payload: Data
    public init(value: LearningPathProgress) throws { pathID = value.pathID; payload = try JSONEncoder().encode(value) }
    public func value() throws -> LearningPathProgress {
        let value = try JSONDecoder().decode(LearningPathProgress.self, from: payload)
        guard value.pathID == pathID else { throw LearningPathError.invalidProgress }
        try LearningPathValidator.validate(value)
        return value
    }
    public func apply(_ value: LearningPathProgress) throws { payload = try JSONEncoder().encode(value) }
}
public enum LearningPathError: Error { case invalidProgress, incompleteActivity }
public struct LearningStepCompletionPolicy {
    public init() {}
    public func isComplete(step: LearningPathStep, attemptedIDs: Set<String>) -> Bool { !step.requiredContentIDs.isEmpty && Set(step.requiredContentIDs).isSubset(of: attemptedIDs) }
    public func isComplete(step: LearningPathStep, attempts: [ExerciseAttempt]) -> Bool {
        isComplete(step: step, attemptedIDs: Set(attempts.filter { $0.snapshot.revision == step.revision }.map { $0.snapshot.id }))
    }
}
public enum LearningPathValidator {
    public static func validate(_ progress: LearningPathProgress) throws {
        guard text(progress.pathID), progress.currentStepID.map(text) ?? true, progress.updatedAt.timeIntervalSince1970.isFinite,
              progress.completedRevisions.count <= 1_000, progress.skippedSteps.count <= 100,
              Set(progress.completedRevisions.map { "\($0.stepID.utf8.count):\($0.stepID):\($0.revision)" }).count == progress.completedRevisions.count,
              Set(progress.skippedStepIDs).count == progress.skippedSteps.count,
              progress.completedRevisions.allSatisfy({ text($0.stepID) && $0.revision > 0 && $0.completedAt.timeIntervalSince1970.isFinite && $0.completedAt <= progress.updatedAt }),
              progress.skippedSteps.allSatisfy({ text($0.stepID) && $0.skippedAt.timeIntervalSince1970.isFinite && $0.skippedAt <= progress.updatedAt }) else { throw LearningPathError.invalidProgress }
    }
    public static func validate(_ progress: LearningPathProgress, steps: [LearningPathStep]) throws {
        try validate(progress)
        try validateSteps(steps)
        let ids = Set(steps.map(\.id))
        guard progress.currentStepID.map({ ids.contains($0) }) ?? true,
              progress.completedRevisions.allSatisfy({ ids.contains($0.stepID) }), Set(progress.skippedStepIDs).isSubset(of: ids) else { throw LearningPathError.invalidProgress }
    }
    public static func validateSteps(_ steps: [LearningPathStep], availableContentIDs: Set<String>? = nil) throws {
        guard !steps.isEmpty, steps.count <= 100, Set(steps.map(\.id)).count == steps.count,
              steps.allSatisfy({ text($0.id) && $0.revision > 0 && !$0.title.isEmpty && $0.title.count <= 200 && text($0.activityKey) && !$0.requiredContentIDs.isEmpty && $0.requiredContentIDs.count <= 1_000 && $0.requiredContentIDs.allSatisfy(text) && Set($0.requiredContentIDs).count == $0.requiredContentIDs.count }) else { throw LearningPathError.invalidProgress }
        if let availableContentIDs { guard steps.allSatisfy({ Set($0.requiredContentIDs).isSubset(of: availableContentIDs) }) else { throw LearningPathError.invalidProgress } }
    }
    private static func text(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= 256 }
}
