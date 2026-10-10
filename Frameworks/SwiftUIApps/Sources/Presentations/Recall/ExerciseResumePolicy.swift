import Foundation
import DataKit

enum ExerciseResumePolicy {
    static func isCurrent(_ checkpoint: ExerciseCheckpoint) -> Bool {
        guard let current = try? currentQuestions(checkpoint) else { return false }
        return current.map { $0.snapshot.fingerprint } == checkpoint.orderedSnapshots.map(\.fingerprint)
    }
    static func currentQuestions(_ checkpoint: ExerciseCheckpoint) throws -> [RecallQuestion] {
        if checkpoint.activityKey.hasPrefix("mistakes:") { return checkpoint.orderedSnapshots.map { historicalQuestion($0) } }
        if checkpoint.activityKey == "grammar" { return ExerciseCatalog.grammar.map { historicalQuestion($0.snapshot) } }
        if checkpoint.activityKey.hasPrefix("reading:") {
            let id = String(checkpoint.activityKey.dropFirst("reading:".count))
            return (ReadingCatalog.passages.first { $0.id == id }?.questions ?? []).map { historicalQuestion($0.snapshot) }
        }
        if checkpoint.activityKey.hasPrefix("path:") {
            let id = String(checkpoint.activityKey.dropFirst("path:".count))
            if let group = StarterPathCatalog.kanaGroups.first(where: { $0.0 == id }) {
                return KanaCatalog.entries.filter { $0.script == group.1 && $0.group == group.2 }.compactMap { RecallSelectionViewModel.kanaQuestion($0, mode: .romanization, listening: false) }
            }
            return StarterPathCatalog.exercises(for: id).map { historicalQuestion($0.snapshot) }
        }
        let listening = checkpoint.activityKey.hasPrefix("listening:")
        let repository = StandardReviewRepository(store: AppComposer.shared.store)
        let items = try SavedStudyKind.allCases.flatMap { try repository.savedItems(kind: $0) }
        var questions = KanaCatalog.entries.flatMap { entry in
            [RecallMode.reading, .romanization].compactMap { RecallSelectionViewModel.kanaQuestion(entry, mode: $0, listening: listening) }
        }
        questions += items.flatMap { item in [RecallMode.reading, .meaning].flatMap { RecallSelectionViewModel.savedQuestions(item, mode: $0, listening: listening) } }
        let byID = Dictionary(questions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return checkpoint.orderedSnapshots.compactMap { byID[$0.id] }
    }
    static func historicalQuestion(_ snapshot: ExerciseSnapshot) -> RecallQuestion {
        RecallQuestion(snapshot: snapshot, suppliedReading: snapshot.questionKind == .listeningReading ? snapshot.acceptedAnswers.first : nil)
    }
}
