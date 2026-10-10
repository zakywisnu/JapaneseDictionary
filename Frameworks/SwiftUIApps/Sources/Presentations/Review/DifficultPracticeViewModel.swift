import Foundation
import Observation
import DataKit

@Observable
final class DifficultPracticeViewModel {
    struct Snapshot {
        var items: [ReviewItem]
        var records: [DifficultyRecord]
        var lists: [StudyList]
        var memberships: [String: Set<SavedStudyID>]
    }
    struct State {
        var snapshot = Snapshot(items: [], records: [], lists: [], memberships: [:])
        var kind: SavedStudyKind?
        var level: String?
        var listID: String?
        var limit: Int? = 20
        var isLoading = true
        var error: String?
    }
    enum Action { case load, setKind(SavedStudyKind?), setLevel(String?), setList(String?), setLimit(Int?), clearFilters }
    private(set) var state = State()
    private let load: () throws -> Snapshot
    init(load: @escaping () throws -> Snapshot) { self.load = load }
    var difficultItems: [ReviewItem] {
        let records = Dictionary(state.snapshot.records.filter { $0.missCount > 0 }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return state.snapshot.items.filter { records[$0.compositeID] != nil }.sorted {
            guard let lhs = records[$0.compositeID], let rhs = records[$1.compositeID] else { return $0.compositeID.key < $1.compositeID.key }
            if lhs.missCount != rhs.missCount { return lhs.missCount > rhs.missCount }
            if lhs.lastMissDate != rhs.lastMissDate { return (lhs.lastMissDate ?? .distantPast) > (rhs.lastMissDate ?? .distantPast) }
            return lhs.id.key < rhs.id.key
        }
    }
    var selected: [ReviewItem] {
        let matching = difficultItems.filter { item in
            (state.kind == nil || item.compositeID.kind == state.kind)
            && (state.level == nil || (item.level.isEmpty ? "Unspecified" : item.level) == state.level)
            && (state.listID == nil || state.snapshot.memberships[state.listID ?? ""]?.contains(item.compositeID) == true)
        }
        return state.limit.map { Array(matching.prefix(max(0, $0))) } ?? matching
    }
    func send(_ action: Action) {
        switch action {
        case .load:
            state.isLoading = true; state.error = nil
            do {
                state.snapshot = try load()
                if let id = state.listID, !state.snapshot.lists.contains(where: { $0.id == id }) { state.listID = nil }
            } catch {
                state.snapshot = .init(items: [], records: [], lists: [], memberships: [:])
                state.error = "Your saved items and difficult ratings couldn't be opened. Try again."
            }
            state.isLoading = false
        case .setKind(let value): state.kind = value
        case .setLevel(let value): state.level = value
        case .setList(let value): state.listID = value
        case .setLimit(let value): state.limit = value
        case .clearFilters: state.kind = nil; state.level = nil; state.listID = nil
        }
    }
}
