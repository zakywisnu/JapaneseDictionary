import Observation

@Observable
final class ReadingPracticeViewModel {
    private let loadPassages: () throws -> [ReadingPassage]
    private(set) var state = State()

    init(loadPassages: @escaping () throws -> [ReadingPassage] = { ReadingCatalog.passages }) {
        self.loadPassages = loadPassages
    }

    func send(_ action: Action) {
        switch action {
        case .load, .retry:
            state.loadState = .loading
            do {
                let passages = try loadPassages()
                guard passages.allSatisfy({ !$0.text.isEmpty && !$0.reading.isEmpty && !$0.translation.isEmpty && !$0.questions.isEmpty && $0.questions.allSatisfy(\.isValid) }) else {
                    state.passages = []; state.loadState = .failed
                    return
                }
                state.passages = passages
                state.loadState = .loaded
            } catch {
                state.passages = []
                state.loadState = .failed
            }
        }
    }

    struct State {
        var loadState: TodayLoadState = .loading
        var passages: [ReadingPassage] = []
    }
    enum Action { case load, retry }
}

@Observable
final class ReadingDetailViewModel {
    private(set) var state = State()
    func send(_ action: Action) {
        switch action {
        case .readingChanged(let value): state.showsReading = value
        case .translationChanged(let value): state.showsTranslation = value
        }
    }
    struct State {
        var showsReading = false
        var showsTranslation = false
    }
    enum Action {
        case readingChanged(Bool), translationChanged(Bool)
    }
}
