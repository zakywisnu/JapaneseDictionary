import Observation
import DataKit
import DomainKit

@Observable
final class StudyListsViewModel {
    struct State {
        var lists: [StudyList] = []
        var isLoading = true
        var error: String?
        var actionError: String?
        var name = ""
        var didCreate = false
    }
    enum Action { case load, setName(String), create, clearActionError }
    var state = State()
    private let useCases: StudyListUseCases
    init(useCases: StudyListUseCases) { self.useCases = useCases }
    func send(_ action: Action) {
        switch action {
        case .setName(let name): state.name = name; state.didCreate = false
        case .clearActionError: state.actionError = nil
        case .load:
            state.isLoading = true
            state.error = nil
            do { state.lists = try useCases.lists() }
            catch { state.lists = []; state.error = "Your study lists couldn't be opened. Try again." }
            state.isLoading = false
        case .create:
            state.didCreate = false
            do {
                _ = try useCases.create(name: state.name)
                state.name = ""
                state.actionError = nil
                state.didCreate = true
                send(.load)
            } catch { state.actionError = error.localizedDescription }
        }
    }
}
