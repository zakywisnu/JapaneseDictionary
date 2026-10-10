import Observation
import DataKit

@Observable
final class PassageVocabularyViewModel {
    private let load: () throws -> StudyList?
    private(set) var state = State()
    init(load: @escaping () throws -> StudyList?) { self.load = load }
    func send(_ action: Action) {
        state.isLoading = true; state.error = nil
        do { state.list = try load() }
        catch { state.error = "Saved vocabulary for this passage couldn't be opened. Try again."; state.list = nil }
        state.isLoading = false
    }
    struct State {
        var isLoading = true
        var list: StudyList?
        var error: String?
        var savedCount: Int { list?.itemCount ?? 0 }
    }
    enum Action { case load }
}
