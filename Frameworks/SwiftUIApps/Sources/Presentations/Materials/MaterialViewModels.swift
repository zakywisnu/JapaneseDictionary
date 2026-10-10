import Foundation
import Observation
import DataKit

@Observable
final class CustomCardEditorViewModel {
    struct Draft: Equatable {
        var prompt = ""
        var answer = ""
        var reading = ""
        var notes = ""
        var category = "other"
        var level: String?
    }
    struct State {
        var draft = Draft()
        var errorMessage: String?
        var needsResetConfirmation = false
        var savedMaterial: StudyMaterial?
    }
    enum Action { case save, confirmSave, cancelConfirmation, dismissError }
    var state = State()
    private let original: StudyMaterial?
    private let saveMaterial: (StudyMaterial) throws -> StudyMaterial
    private let newID = UUID().uuidString
    init(material: StudyMaterial?, save: @escaping (StudyMaterial) throws -> StudyMaterial) {
        original = material
        saveMaterial = save
        if let material {
            state.draft = Draft(prompt: material.prompt, answer: material.answer, reading: material.reading ?? "", notes: material.notes ?? "", category: material.category ?? "other", level: material.level)
        }
    }
    convenience init(material: StudyMaterial? = nil, repository: StandardStudyMaterialRepository) {
        self.init(material: material, save: { try repository.save($0) })
    }
    var isEditing: Bool { original != nil }
    func send(_ action: Action) {
        switch action {
        case .save:
            guard let value = validatedMaterial() else { return }
            if let original, original.prompt != value.prompt || original.answer != value.answer || original.reading != value.reading {
                state.needsResetConfirmation = true
            } else { persist(value) }
        case .confirmSave:
            state.needsResetConfirmation = false
            if let value = validatedMaterial() { persist(value) }
        case .cancelConfirmation: state.needsResetConfirmation = false
        case .dismissError: state.errorMessage = nil
        }
    }
    private func validatedMaterial() -> StudyMaterial? {
        let draft = state.draft
        let prompt = draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = draft.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !answer.isEmpty else {
            state.errorMessage = "Enter a prompt and answer before saving."; return nil
        }
        guard prompt.count <= 500, answer.count <= 4_000, draft.reading.count <= 500, draft.notes.count <= 4_000 else {
            state.errorMessage = "Shorten the prompt and reading to 500 characters, and the answer and notes to 4,000."; return nil
        }
        let now = Date()
        return StudyMaterial(id: original?.id ?? newID, kind: .customCard, prompt: prompt, answer: answer, reading: optional(draft.reading), level: draft.level, notes: optional(draft.notes), category: draft.category, createdAt: original?.createdAt ?? now, updatedAt: now)
    }
    private func optional(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    private func persist(_ material: StudyMaterial) {
        do { state.savedMaterial = try saveMaterial(material); state.errorMessage = nil }
        catch { state.errorMessage = "Your card couldn't be saved. Your draft is still here. Try again." }
    }
}

@Observable
final class MaterialLibraryViewModel {
    enum Mode: Equatable { case saved(SavedStudyKind), bundled }
    struct State {
        var query = ""
        var kind: SavedStudyKind = .grammar
        var level: String?
        var results: [StudyMaterial] = []
        var savedSourceKeys: Set<String> = []
        var loadState: TodayLoadState = .loading
        var errorMessage: String?
    }
    enum Action { case load, retry, queryChanged(String), levelChanged(String?), kindChanged(SavedStudyKind), clearFilters }
    var state = State()
    let mode: Mode
    private let loadSaved: () throws -> [StudyMaterial]
    private let loadCatalog: () throws -> [StudyMaterial]
    private var materials: [StudyMaterial] = []
    init(mode: Mode, loadSaved: @escaping () throws -> [StudyMaterial], loadCatalog: @escaping () throws -> [StudyMaterial]) {
        self.mode = mode; self.loadSaved = loadSaved; self.loadCatalog = loadCatalog
        if case .saved(let kind) = mode { state.kind = kind }
    }
    convenience init(mode: Mode = .bundled, repository: StandardStudyMaterialRepository, catalog: LessonCatalogRepository) {
        self.init(mode: mode, loadSaved: { try repository.materials() }, loadCatalog: { try catalog.materials() })
    }
    var reviewMaterials: [StudyMaterial] { materials.filter { $0.kind == state.kind } }
    var title: String {
        if mode == .bundled { return "Lessons" }
        switch state.kind { case .grammar: return "Grammar"; case .sentence: return "Sentences"; default: return "Your cards" }
    }
    func isSaved(_ material: StudyMaterial) -> Bool { Self.sourceKey(material).map(state.savedSourceKeys.contains) ?? false }
    func send(_ action: Action) {
        switch action {
        case .load, .retry:
            state.loadState = .loading
            state.errorMessage = nil
            do {
                let saved = try loadSaved()
                state.savedSourceKeys = Set(saved.compactMap(Self.sourceKey))
                switch mode { case .bundled: materials = try loadCatalog(); case .saved: materials = saved }
                state.loadState = .loaded; filter()
            } catch {
                materials = []; state.results = []; state.loadState = .failed
                state.errorMessage = mode == .bundled ? "The bundled lessons or saved collection couldn't be opened. Try again." : "Your saved material couldn't be opened. Try again."
            }
        case .queryChanged(let query): state.query = query; filter()
        case .levelChanged(let level): state.level = level; filter()
        case .kindChanged(let kind): state.kind = kind; filter()
        case .clearFilters: state.query = ""; state.level = nil; filter()
        }
    }
    private func filter() {
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        state.results = materials.filter {
            $0.kind == state.kind && (state.level == nil || ($0.level ?? "") == state.level) &&
            (query.isEmpty || [$0.prompt, $0.answer, $0.reading ?? "", $0.notes ?? ""].contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }
    static func sourceKey(_ material: StudyMaterial) -> String? {
        material.source.map { material.kind.rawValue + ":" + $0.provider + ":" + $0.sourceID }
    }
}

@Observable
final class MaterialDetailViewModel {
    enum Mode { case saved, bundled }
    struct State {
        var material: StudyMaterial
        var savedMaterial: StudyMaterial?
        var loadState: TodayLoadState = .loading
        var errorMessage: String?
        var didDelete = false
    }
    enum Action { case load, save, delete, dismissError }
    var state: State
    let mode: Mode
    private let loadSaved: () throws -> [StudyMaterial]
    private let saveMaterial: (StudyMaterial) throws -> StudyMaterial
    private let deleteMaterial: (SavedStudyID) throws -> Void
    init(material: StudyMaterial, mode: Mode, loadSaved: @escaping () throws -> [StudyMaterial], save: @escaping (StudyMaterial) throws -> StudyMaterial, delete: @escaping (SavedStudyID) throws -> Void) {
        state = State(material: material); self.mode = mode; self.loadSaved = loadSaved; saveMaterial = save; deleteMaterial = delete
    }
    convenience init(material: StudyMaterial, mode: Mode, repository: StandardStudyMaterialRepository, catalog: LessonCatalogRepository) {
        self.init(material: material, mode: mode, loadSaved: { try repository.materials() }, save: { try repository.save($0) }, delete: { try repository.delete($0) })
    }
    var canSave: Bool { mode == .bundled && state.loadState == .loaded && state.savedMaterial == nil }
    func send(_ action: Action) {
        switch action {
        case .load:
            do {
                let saved = try loadSaved()
                if mode == .saved {
                    guard let current = saved.first(where: { $0.kind == state.material.kind && $0.id == state.material.id }) else {
                        state.loadState = .failed; state.errorMessage = "This item is no longer in your collection. Return to the collection to choose another item."; return
                    }
                    state.material = current; state.savedMaterial = current
                } else {
                    state.savedMaterial = saved.first { MaterialLibraryViewModel.sourceKey($0) == MaterialLibraryViewModel.sourceKey(state.material) && MaterialLibraryViewModel.sourceKey($0) != nil }
                }
                state.loadState = .loaded; state.errorMessage = nil
            } catch { state.loadState = .failed; state.errorMessage = "Your saved collection couldn't be read. Try again." }
        case .save:
            guard canSave else { return }
            do { state.savedMaterial = try saveMaterial(state.material); state.errorMessage = nil }
            catch { state.errorMessage = "This lesson couldn't be saved. Try again." }
        case .delete:
            guard mode == .saved else { return }
            do { try deleteMaterial(.init(kind: state.material.kind, id: state.material.id)); state.didDelete = true }
            catch { state.errorMessage = "This item couldn't be removed. Try again." }
        case .dismissError: state.errorMessage = nil
        }
    }
}
