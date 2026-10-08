import Foundation
import SwiftData

public protocol DailyGoalRepository {
    func target() throws -> Int?
    func setTarget(_ target: Int?) throws
    func activities(dayKey: String) throws -> [PracticeActivity]
    func record(_ activity: PracticeActivity) throws
}

public enum DailyGoalError: Error {
    case invalidTarget
}

public final class StandardDailyGoalRepository: DailyGoalRepository {
    private let store: StudyStore
    private let saveContext: (ModelContext) throws -> Void

    public init(store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.store = store
        saveContext = save
    }

    public func target() throws -> Int? {
        let models = try store.makeContext().fetch(FetchDescriptor<DailyGoalSettingsModel>())
        guard let model = models.first else { return 10 }
        return model.target
    }

    public func setTarget(_ target: Int?) throws {
        guard target.map({ [5, 10, 20, 30].contains($0) }) ?? true else { throw DailyGoalError.invalidTarget }
        let context = store.makeContext()
        do {
            if let model = try context.fetch(FetchDescriptor<DailyGoalSettingsModel>()).first {
                model.target = target
            } else {
                context.insert(DailyGoalSettingsModel(settings: .init(target: target)))
            }
            try saveContext(context)
            store.refreshContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    public func activities(dayKey: String) throws -> [PracticeActivity] {
        try store.makeContext().fetch(FetchDescriptor<PracticeActivityModel>(predicate: #Predicate { $0.dayKey == dayKey }))
            .map(\.value).sorted { $0.key < $1.key }
    }

    public func record(_ activity: PracticeActivity) throws {
        try BackupValidator.validateActivity(activity)
        let context = store.makeContext()
        do {
            guard try insertPracticeActivityIfNeeded(activity, context: context) else { return }
            try saveContext(context)
            store.refreshContext()
        } catch {
            context.rollback()
            throw error
        }
    }
}

@discardableResult
func insertPracticeActivityIfNeeded(_ activity: PracticeActivity, context: ModelContext) throws -> Bool {
    let key = activity.key
    let descriptor = FetchDescriptor<PracticeActivityModel>(predicate: #Predicate { $0.key == key })
    // Historical completions remain valid after deletion; only new completions need a saved learner.
    guard try context.fetch(descriptor).isEmpty else { return false }
    try requireSavedItem(activity.studyID, context: context)
    context.insert(PracticeActivityModel(activity: activity))
    return true
}
