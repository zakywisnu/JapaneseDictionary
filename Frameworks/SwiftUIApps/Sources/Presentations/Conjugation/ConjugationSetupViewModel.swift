import Foundation
import Observation
import DataKit
import DomainKit

@MainActor
@Observable
final class ConjugationSetupViewModel {
    private let loadCatalog: () throws -> AppliedPracticeCatalog
    private let save: (ExerciseCheckpoint) throws -> Void
    private let topicID: String?
    private let lemma: String?
    private var activities: [AppliedPracticeActivity] = []
    private(set) var state = State()
    init(topicID: String? = nil, lemma: String? = nil, load: @escaping () throws -> AppliedPracticeCatalog, save: @escaping (ExerciseCheckpoint) throws -> Void) {
        self.topicID = topicID; self.lemma = lemma; loadCatalog = load; self.save = save
    }
    var candidates: [ExerciseSnapshot] {
        activities.filter {
            (state.classID == nil || $0.classID == state.classID) && (state.formID == nil || $0.formID == state.formID)
        }.flatMap(\.questions).filter {
            (topicID == nil || $0.metadata?.topicID == topicID) && (lemma == nil || $0.metadata?.stimulus == lemma)
        }.sorted { $0.id < $1.id }
    }
    var selected: [ExerciseSnapshot] { Array(candidates.prefix(state.limit ?? candidates.count)) }
    func send(_ action: Action) {
        switch action {
        case .load:
            resetStart()
            state.isLoading = true; state.error = nil
            do { activities = try loadCatalog().activities.filter { $0.kind == .conjugation } }
            catch { activities = []; state.error = "The bundled conjugation practice couldn't be opened. Try again." }
            state.isLoading = false
        case .classID(let value): state.classID = value; resetStart()
        case .formID(let value): state.formID = value; resetStart()
        case .limit(let value): state.limit = value; resetStart()
        case .start:
            guard !state.isLoading, state.error == nil, !selected.isEmpty else { return }
            let key = "conjugation:\(state.classID ?? "all"):\(state.formID ?? "all"):\(topicID ?? lemma ?? "all"):\(state.limit.map(String.init) ?? "all")"
            do {
                try save(.init(activityKey: key, sessionID: UUID(), orderedSnapshots: selected, position: 0, updatedAt: Date()))
                state.startError = nil; state.startedKey = key
            } catch { state.startError = "Your practice session couldn't be saved. Tap Start practice to try again." }
        }
    }
    private func resetStart() { state.startedKey = nil; state.startError = nil }
    struct State {
        var isLoading = true
        var error: String?
        var startError: String?
        var classID: String?
        var formID: String?
        var limit: Int? = 5
        var startedKey: String?
    }
    enum Action { case load, classID(String?), formID(String?), limit(Int?), start }
}
