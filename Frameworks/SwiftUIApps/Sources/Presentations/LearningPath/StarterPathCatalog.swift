import DataKit

enum StarterPathCatalog {
    static let id = "original-beginner-v1"
    static let kanaGroups: [(String, KanaScript, KanaGroup)] = [
        ("hiragana-basic", .hiragana, .basic), ("hiragana-voiced", .hiragana, .voiced),
        ("katakana-basic", .katakana, .basic), ("contracted", .hiragana, .contracted)
    ]
    static let grammarIDs = ["topic", "object", "destination", "location", "possession", "also", "question", "time"]
    static let verbIDs = ["existence", "living", "past", "negative", "request"]
    static var steps: [LearningPathStep] {
        kanaGroups.map { id, script, group in
            .init(id: id, revision: 1, title: script.rawValue + " · " + group.rawValue, activityKey: "path:" + id,
                  requiredContentIDs: KanaCatalog.entries.filter { $0.script == script && $0.group == group }.map(\.id))
        } + [
            .init(id: "particles", revision: 1, title: "Particles in context", activityKey: "path:particles", requiredContentIDs: grammarIDs),
            .init(id: "morning", revision: 1, title: "Read a quiet morning", activityKey: "path:morning", requiredContentIDs: ReadingCatalog.passages.first { $0.id == "morning" }!.questions.map(\.id)),
            .init(id: "polite-verbs", revision: 1, title: "Polite verbs", activityKey: "path:polite-verbs", requiredContentIDs: verbIDs),
            .init(id: "more-reading", revision: 1, title: "Read more short passages", activityKey: "path:more-reading", requiredContentIDs: ReadingCatalog.passages.filter { $0.id != "morning" }.flatMap { $0.questions.map(\.id) })
        ]
    }
    static func exercises(for id: String) -> [PracticeExercise] {
        switch id {
        case "particles": return ExerciseCatalog.grammar.filter { grammarIDs.contains($0.id) }
        case "polite-verbs": return ExerciseCatalog.grammar.filter { verbIDs.contains($0.id) }
        case "morning": return ReadingCatalog.passages.first { $0.id == id }?.questions ?? []
        case "more-reading": return ReadingCatalog.passages.filter { $0.id != "morning" }.flatMap(\.questions)
        default: return []
        }
    }
}
