import Foundation
import DataKit

public struct LearningDestination: Equatable {
    public var activityKey: String
    public var stepID: String?
    public var sessionID: UUID?
    public init(activityKey: String, stepID: String? = nil, sessionID: UUID? = nil) { self.activityKey = activityKey; self.stepID = stepID; self.sessionID = sessionID }
}
public struct ContinueLearningUseCase {
    private let loadCheckpoints: () throws -> [ExerciseCheckpoint]
    private let loadProgress: () throws -> LearningPathProgress?
    private let steps: [LearningPathStep]
    private let validCheckpoint: (ExerciseCheckpoint) -> Bool
    public init(loadCheckpoints: @escaping () throws -> [ExerciseCheckpoint], loadProgress: @escaping () throws -> LearningPathProgress?, steps: [LearningPathStep], validCheckpoint: @escaping (ExerciseCheckpoint) -> Bool) {
        self.loadCheckpoints = loadCheckpoints; self.loadProgress = loadProgress; self.steps = steps; self.validCheckpoint = validCheckpoint
    }
    public func execute() throws -> LearningDestination? {
        try LearningPathValidator.validateSteps(steps)
        let checkpoints = try loadCheckpoints().filter(validCheckpoint).sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            if $0.activityKey != $1.activityKey { return $0.activityKey < $1.activityKey }
            return $0.sessionID.uuidString < $1.sessionID.uuidString
        }
        if let checkpoint = checkpoints.first { return .init(activityKey: checkpoint.activityKey, sessionID: checkpoint.sessionID) }
        let progress = try loadProgress()
        if let progress {
            try LearningPathValidator.validate(progress, steps: steps)
            if let current = steps.first(where: { $0.id == progress.currentStepID }), !progress.skippedStepIDs.contains(current.id) {
                return .init(activityKey: current.activityKey, stepID: current.id)
            }
        }
        guard let next = steps.first(where: { !(progress?.isComplete($0) ?? false) && !(progress?.skippedStepIDs.contains($0.id) ?? false) }) else { return nil }
        return .init(activityKey: next.activityKey, stepID: next.id)
    }
}
