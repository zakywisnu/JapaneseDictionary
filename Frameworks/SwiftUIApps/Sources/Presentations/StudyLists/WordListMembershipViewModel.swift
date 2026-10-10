import Observation
import DataKit
import DomainKit

@Observable
final class WordListMembershipViewModel {
    struct State {
        var lists: [StudyList] = []
        var selected: Set<String> = []
        var original: Set<String> = []
        var isLoading = true
        var error: String?
        var saveError: String?
        var didSave = false
    }
    enum Action { case load, refreshLists, toggle(String), save, cancel }
    var state = State()
    private let id: SavedStudyID
    private let useCases: StudyListUseCases
    init(wordID: String, useCases: StudyListUseCases) { self.id = .init(kind: .word, id: wordID); self.useCases = useCases }
    init(id: SavedStudyID, useCases: StudyListUseCases) { self.id = id; self.useCases = useCases }
    func send(_ action: Action) {
        switch action {
        case .load:
            state.isLoading = true; state.error = nil
            do {
                let lists = try useCases.lists()
                let selected = try useCases.listIDs(id: id)
                state.lists = lists; state.original = selected; state.selected = selected
            } catch { state.error = (error as? StudyListError)?.errorDescription ?? "This item's lists couldn't be opened. Try again." }
            state.isLoading = false
        case .refreshLists:
            do {
                state.lists = try useCases.lists()
                let available = Set(state.lists.map(\.id))
                state.selected.formIntersection(available)
                state.original.formIntersection(available)
            }
            catch { state.saveError = "Study lists couldn't be reloaded. Try again." }
        case .toggle(let id):
            if state.selected.contains(id) { state.selected.remove(id) } else { state.selected.insert(id) }
            state.didSave = false
        case .cancel: state.selected = state.original; state.didSave = false
        case .save:
            state.didSave = false
            do { try useCases.setLists(id: id, listIDs: state.selected); state.original = state.selected; state.didSave = true; state.saveError = nil }
            catch { state.saveError = "This item's lists couldn't be saved. Try again. Your choices are still here." }
        }
    }
}
