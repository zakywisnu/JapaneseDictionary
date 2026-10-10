import Observation
import DataKit
import DomainKit

@Observable
final class StudyListDetailViewModel {
    struct State {
        var list: StudyList?
        var words: [SavedStudyItem] = []
        var isLoading = true
        var isMissing = false
        var error: String?
        var actionError: String?
        var name = ""
        var didRename = false
        var didDelete = false
    }
    enum Action { case load, setName(String), rename, delete, remove(String), removeItem(SavedStudyID), clearActionError }
    var state = State()
    let id: String
    private let useCases: StudyListUseCases
    init(id: String, useCases: StudyListUseCases) { self.id = id; self.useCases = useCases }
    func send(_ action: Action) {
        switch action {
        case .load:
            state.isLoading = true; state.error = nil; state.isMissing = false
            do {
                guard let list = try useCases.lists().first(where: { $0.id == id }) else { throw StudyListError.missingList }
                state.words = try useCases.items(listID: id)
                state.list = list
            } catch {
                state.list = nil; state.words = []
                state.isMissing = (error as? StudyListError) == .missingList
                state.error = state.isMissing ? "This list no longer exists. Return to Study lists." : "This list couldn't be opened. Try again."
            }
            state.isLoading = false
        case .setName(let name): state.name = name; state.didRename = false
        case .clearActionError: state.actionError = nil
        case .rename:
            state.didRename = false
            do { try useCases.rename(id: id, name: state.name); state.didRename = true; state.actionError = nil; send(.load) }
            catch { state.actionError = error.localizedDescription }
        case .delete:
            do { try useCases.delete(id: id); state.didDelete = true }
            catch { state.actionError = "This list couldn't be deleted. Try again." }
        case .remove(let wordID):
            do { try useCases.removeWord(listID: id, wordID: wordID); send(.load) }
            catch { state.actionError = "This word couldn't be removed from the list. Try again." }
        case .removeItem(let itemID):
            do { try useCases.removeItem(listID: id, id: itemID); send(.load) }
            catch { state.actionError = "This item couldn't be removed from the list. Try again." }
        }
    }
}
