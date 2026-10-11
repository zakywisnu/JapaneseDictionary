import Foundation

public struct AppliedPracticeCatalogRepository {
    public let catalog: AppliedPracticeCatalog
    public init(data: Data) throws {
        catalog = try JSONDecoder().decode(AppliedPracticeCatalog.self, from: data)
        try Self.validate(catalog)
    }
    public static func bundled() throws -> AppliedPracticeCatalog {
        guard let url = Bundle(for: PracticeBundleMarker.self).url(forResource: "applied-practice", withExtension: "json") else { throw ExerciseHistoryError.invalidRecord }
        return try Self(data: Data(contentsOf: url)).catalog
    }
    public static func validate(_ catalog: AppliedPracticeCatalog) throws {
        guard catalog.formatVersion == 1, catalog.activities.count <= 1_000, catalog.contexts.count <= 10_000,
              Set(catalog.activities.map(\.id)).count == catalog.activities.count,
              Set(catalog.contexts.map(\.stableID)).count == catalog.contexts.count else { throw ExerciseHistoryError.invalidRecord }
        var questionIDs = Set<String>()
        for activity in catalog.activities {
            guard practiceText(activity.id, max: 256), practiceText(activity.title), !activity.questions.isEmpty,
                  activity.classID.map({ practiceText($0, max: 256) }) ?? true,
                  activity.formID.map({ practiceText($0, max: 256) }) ?? true else { throw ExerciseHistoryError.invalidRecord }
            for question in activity.questions {
                try ExerciseHistoryValidator.validateSnapshot(question)
                guard questionIDs.insert(question.id).inserted, question.questionKind.rawValue == activity.kind.rawValue,
                      let metadata = question.metadata, !metadata.assisted else { throw ExerciseHistoryError.invalidRecord }
                try validatePracticeReview(metadata.review, hash: question.computedReviewHash)
            }
        }
        for context in catalog.contexts {
            guard practiceText(context.stableID, max: 256), [context.word.headword, context.word.reading, context.word.level].allSatisfy({ practiceText($0, max: 500) }), context.catalogID.map({ practiceText($0, max: 256) }) ?? true,
                  !context.verifiedMeanings.isEmpty, context.verifiedMeanings.count <= 100,
                  context.verifiedMeanings.allSatisfy({ practiceText($0, max: 500) }),
                  [context.cloze, context.japanese, context.reading, context.translation, context.source].allSatisfy({ practiceText($0) }) else { throw ExerciseHistoryError.invalidRecord }
            try validatePracticeReview(context.review, hash: context.computedContentHash)
        }
    }
}
private final class PracticeBundleMarker {}
func practiceText(_ value: String, max: Int = 20_000) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= max }
func validatePracticeReview(_ review: PracticeContentReview?, hash: String) throws {
    guard let review, practiceText(review.reviewer, max: 256), practiceText(review.date, max: 100),
          practiceText(review.method, max: 1_000), review.contentHash == hash else { throw ExerciseHistoryError.invalidRecord }
}
