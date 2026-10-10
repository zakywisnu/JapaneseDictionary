import Foundation
import Observation
import DataKit

@Observable
final class DailyStudyPlanViewModel {
    struct Snapshot {
        var items: [ReviewItem]
        var reviews: [ReviewRecord]
        var difficulties: [DifficultyRecord]
        var completed: Set<SavedStudyID>
        var target: Int?
    }
    struct Batch: Identifiable {
        enum Kind: String { case due, difficult, firstReview }
        let kind: Kind
        let items: [ReviewItem]
        var id: String { kind.rawValue }
        var title: String {
            switch kind {
            case .due: return "Due reviews"
            case .difficult: return "Difficult items"
            case .firstReview: return "First reviews"
            }
        }
        var explanation: String {
            switch kind {
            case .due: return "These scheduled reviews are due. Ratings update their next review dates."
            case .difficult: return "You marked these Again. Practice leaves their due dates unchanged."
            case .firstReview: return "These saved items have no review schedule yet. Ratings set their first review dates."
            }
        }
        var session: ReviewSession {
            ReviewSession(items: items, origin: kind == .difficult ? .difficult : .due, returnTitle: "Back to daily study plan")
        }
    }
    struct State {
        var isLoading = true
        var error: String?
        var snapshot: Snapshot?
    }
    enum Action { case load }
    private(set) var state = State()
    private let load: () throws -> Snapshot
    private let now: () -> Date
    init(load: @escaping () throws -> Snapshot, now: @escaping () -> Date = Date.init) {
        self.load = load; self.now = now
    }
    var goalReached: Bool {
        guard let snapshot = state.snapshot, let target = snapshot.target else { return false }
        return snapshot.completed.count >= target
    }
    var batches: [Batch] {
        guard let snapshot = state.snapshot else { return [] }
        let reviews = Dictionary(snapshot.reviews.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let difficulty = Dictionary(snapshot.difficulties.filter { $0.missCount > 0 }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let instant = now()
        let items = Dictionary(snapshot.items.map { ($0.compositeID, $0) }, uniquingKeysWith: { first, _ in first }).values
            .filter { !snapshot.completed.contains($0.compositeID) }
        let due = items.filter { reviews[$0.compositeID].map { $0.dueDate <= instant } ?? false }.sorted {
            let lhs = reviews[$0.compositeID]?.dueDate ?? .distantPast
            let rhs = reviews[$1.compositeID]?.dueDate ?? .distantPast
            return lhs == rhs ? $0.compositeID.key < $1.compositeID.key : lhs < rhs
        }
        let dueIDs = Set(due.map(\.compositeID))
        let difficult = items.filter { difficulty[$0.compositeID] != nil && !dueIDs.contains($0.compositeID) }.sorted {
            let lhs = difficulty[$0.compositeID]?.missCount ?? 0
            let rhs = difficulty[$1.compositeID]?.missCount ?? 0
            if lhs != rhs { return lhs > rhs }
            let leftDate = difficulty[$0.compositeID]?.lastMissDate ?? .distantPast
            let rightDate = difficulty[$1.compositeID]?.lastMissDate ?? .distantPast
            return leftDate == rightDate ? $0.compositeID.key < $1.compositeID.key : leftDate > rightDate
        }
        let excluded = dueIDs.union(difficult.map(\.compositeID))
        let first = items.filter { reviews[$0.compositeID] == nil && !excluded.contains($0.compositeID) }.sorted {
            let lhs = $0.dateAdded ?? .distantPast, rhs = $1.dateAdded ?? .distantPast
            return lhs == rhs ? $0.compositeID.key < $1.compositeID.key : lhs < rhs
        }
        let remaining = snapshot.target.map { max(0, $0 - snapshot.completed.count) }
        var budget = min(10, remaining == 0 ? 10 : remaining ?? 10)
        var result: [Batch] = []
        for (kind, candidates) in [(Batch.Kind.due, due), (.difficult, difficult), (.firstReview, first)] {
            let selected = Array(candidates.prefix(budget))
            if !selected.isEmpty { result.append(.init(kind: kind, items: selected)); budget -= selected.count }
        }
        return result
    }
    func send(_ action: Action) {
        state.isLoading = true; state.error = nil; state.snapshot = nil
        do { state.snapshot = try load() }
        catch { state.error = "Your saved items, review dates or today's activity couldn't be opened. Try again." }
        state.isLoading = false
    }
}
