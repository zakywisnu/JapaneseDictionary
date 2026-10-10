import Observation

struct PracticeExercise: Identifiable, Equatable {
    enum Kind: String { case choice, fillBlank }
    let id: String
    let kind: Kind
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String

    var isValid: Bool {
        !id.isEmpty && !prompt.isEmpty && choices.count >= 2 &&
        Set(choices).count == choices.count && choices.indices.contains(correctIndex) && !explanation.isEmpty
    }
}

@Observable
final class ExerciseSessionViewModel {
    private let exercises: [PracticeExercise]
    private(set) var state = State()

    init(exercises: [PracticeExercise]) {
        self.exercises = exercises
        state.total = exercises.count
        state.hasInvalidContent = exercises.contains { !$0.isValid }
    }

    var current: PracticeExercise? {
        guard !state.isComplete, !state.hasInvalidContent, exercises.indices.contains(state.position) else { return nil }
        return exercises[state.position]
    }

    func send(_ action: Action) {
        switch action {
        case .choose(let index):
            guard state.selectedIndex == nil, let current, current.choices.indices.contains(index) else { return }
            state.selectedIndex = index
            if index == current.correctIndex { state.correctCount += 1 }
        case .next:
            guard state.selectedIndex != nil, current != nil else { return }
            if state.position + 1 == exercises.count { state.isComplete = true }
            else { state.position += 1; state.selectedIndex = nil }
        case .restart:
            state = State(total: exercises.count, hasInvalidContent: exercises.contains { !$0.isValid })
        }
    }

    struct State {
        var position = 0
        var selectedIndex: Int?
        var correctCount = 0
        var isComplete = false
        var total = 0
        var hasInvalidContent = false
    }
    enum Action { case choose(Int), next, restart }
}
