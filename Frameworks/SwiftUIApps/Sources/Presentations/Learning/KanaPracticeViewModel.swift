import Foundation
import Observation
import DataKit

@Observable
final class KanaPracticeViewModel {
    struct State {
        var script: KanaScript = .hiragana
        var group: KanaGroup = .basic
        var entries: [KanaEntry] = []
        var selected: Set<String> = []
        var isLoading = true
        var error: String?
        var saveError: String?
        var session: ReviewSession?
    }
    enum Action { case load, script(KanaScript), group(KanaGroup), toggle(String), selectVisible, saveAndPractice }
    private(set) var state = State()
    private let load: () throws -> [KanaEntry]
    private let save: ([KanaEntry]) throws -> [StudyMaterial]
    init(load: @escaping () throws -> [KanaEntry] = { KanaCatalog.entries }, save: @escaping ([KanaEntry]) throws -> [StudyMaterial]) {
        self.load = load; self.save = save
    }
    var visible: [KanaEntry] { state.entries.filter { $0.script == state.script && $0.group == state.group } }
    var selectedEntries: [KanaEntry] { state.entries.filter { state.selected.contains($0.id) } }
    func send(_ action: Action) {
        switch action {
        case .load:
            state.isLoading = true; state.error = nil
            do { state.entries = try load(); state.selected.formIntersection(Set(state.entries.map(\.id))) }
            catch { state.entries = []; state.error = "The kana catalog couldn't be opened. Try again." }
            state.isLoading = false
        case .script(let value): state.script = value
        case .group(let value): state.group = value
        case .toggle(let id): if state.selected.contains(id) { state.selected.remove(id) } else { state.selected.insert(id) }
        case .selectVisible: state.selected.formUnion(visible.map(\.id))
        case .saveAndPractice:
            state.session = nil; state.saveError = nil
            guard !selectedEntries.isEmpty else { return }
            do {
                let materials = try save(selectedEntries)
                var session = ReviewSession(items: materials.map(ReviewItem.init(material:)), origin: .collection)
                session.returnTitle = "Back to Kana"
                state.session = session
            } catch {
                state.saveError = "The selected kana couldn't all be saved. Any cards already saved stay in Collection. Try Save and practice again."
            }
        }
    }
}
