import Foundation
import SwiftData

public final class StudyStore {
    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "JapaneseDictionary.store")
    }
    public let container: ModelContainer
    public private(set) var context: ModelContext

    public init(url: URL = StudyStore.defaultURL, inMemory: Bool = false) throws {
        let schema = Schema([KanjiDataModel.self, KotobaDataModel.self, WordsProgressModel.self, ReviewRecordModel.self, StudyListModel.self, StudyListMembershipModel.self, DailyGoalSettingsModel.self, PracticeActivityModel.self, StudyMaterialModel.self, DifficultyRecordModel.self, StudyItemMembershipModel.self, ExerciseAttemptModel.self, ExerciseCheckpointModel.self, ReviewRatingEventModel.self, LearningPathProgressModel.self])
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: url)
        container = try ModelContainer(for: schema, configurations: configuration)
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    public func makeContext() -> ModelContext {
        let result = ModelContext(container)
        result.autosaveEnabled = false
        return result
    }

    public func refreshContext() {
        context = makeContext()
    }
}
