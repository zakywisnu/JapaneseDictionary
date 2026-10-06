import Observation

@Observable
final class ReviewViewModel {
    private(set) var state: State

    init(session: ReviewSession) {
        state = State(session: session)
    }

    @MainActor
    func send(_ action: Action) {
        guard !state.session.items.isEmpty else { return }
        switch action {
        case .reveal:
            guard !state.isComplete else { return }
            state.isAnswerVisible = true
        case .next:
            guard state.isAnswerVisible, !state.isComplete else { return }
            if state.index == state.session.items.count - 1 {
                state.isComplete = true
            } else {
                state.index += 1
                state.isAnswerVisible = false
            }
        case .previous:
            guard state.index > 0, !state.isComplete else { return }
            state.index -= 1
            state.isAnswerVisible = false
        case .restart:
            state.index = 0
            state.isAnswerVisible = false
            state.isComplete = false
        }
    }

    struct State {
        let session: ReviewSession
        var index = 0
        var isAnswerVisible = false
        var isComplete = false

        var currentItem: ReviewItem? {
            guard session.items.indices.contains(index) else { return nil }
            return session.items[index]
        }

        var isLastItem: Bool { index == session.items.count - 1 }
        var canGoBack: Bool { index > 0 && !isComplete }
    }

    enum Action {
        case reveal
        case next
        case previous
        case restart
    }
}
