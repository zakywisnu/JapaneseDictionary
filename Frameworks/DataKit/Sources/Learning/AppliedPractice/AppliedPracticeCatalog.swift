import Foundation

public enum PracticeActivityKind: String, Codable, Hashable { case conjugation, sentenceOrder, listeningComprehension }
public struct AppliedPracticeActivity: Codable, Hashable {
    public var id: String
    public var title: String
    public var kind: PracticeActivityKind
    public var classID: String?
    public var formID: String?
    public var questions: [ExerciseSnapshot]
    public init(id: String, title: String, kind: PracticeActivityKind, classID: String? = nil, formID: String? = nil, questions: [ExerciseSnapshot]) {
        self.id = id; self.title = title; self.kind = kind; self.classID = classID; self.formID = formID; self.questions = questions
    }
}
public struct ReviewedContext: Codable, Hashable {
    public var stableID: String
    public var word: ExampleWordKey
    public var catalogID: String?
    public var verifiedMeanings: [String]
    public var cloze: String
    public var japanese: String
    public var reading: String
    public var translation: String
    public var source: String
    public var review: PracticeContentReview?
    public init(stableID: String, word: ExampleWordKey, catalogID: String? = nil, verifiedMeanings: [String], cloze: String, japanese: String, reading: String, translation: String, source: String, review: PracticeContentReview? = nil) {
        self.stableID = stableID; self.word = word; self.catalogID = catalogID; self.verifiedMeanings = verifiedMeanings; self.cloze = cloze; self.japanese = japanese; self.reading = reading; self.translation = translation; self.source = source; self.review = review
    }
    public var computedContentHash: String { var copy = self; copy.review = nil; return practiceHash(copy) }
}
public struct AppliedPracticeCatalog: Codable, Hashable {
    public var formatVersion: Int
    public var activities: [AppliedPracticeActivity]
    public var contexts: [ReviewedContext]
    public init(formatVersion: Int = 1, activities: [AppliedPracticeActivity], contexts: [ReviewedContext]) { self.formatVersion = formatVersion; self.activities = activities; self.contexts = contexts }
}
