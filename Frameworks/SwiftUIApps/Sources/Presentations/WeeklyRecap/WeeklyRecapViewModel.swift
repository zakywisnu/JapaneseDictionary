import Foundation
import Observation
import DomainKit

@Observable final class WeeklyRecapViewModel {
    struct State { var loading = false; var error: String?; var recap: WeeklyRecap? }
    enum Action { case load, retry, openFocus }
    private(set) var state = State()
    private let load: () throws -> WeeklyRecap
    private let open: (WeeklyFocusDestination) -> Void
    init(load: @escaping () throws -> WeeklyRecap, open: @escaping (WeeklyFocusDestination) -> Void = { _ in }) { self.load = load; self.open = open }
    func send(_ action: Action) {
        switch action {
        case .load, .retry:
            state.loading = true; state.error = nil; state.recap = nil
            defer { state.loading = false }
            do { state.recap = try load() } catch { state.error = "Retained practice history couldn't be read. Try loading it again." }
        case .openFocus:
            guard let recap = state.recap, let focus = recap.focus else { return }
            if case .topic(_, let id) = focus.destination, !recap.availableFocusIDs.contains(id) { return }
            open(focus.destination)
        }
    }
}
