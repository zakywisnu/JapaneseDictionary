import Observation
import Foundation
import DataKit
import DomainKit

@Observable
final class ReviewViewModel {
    private(set) var state: State

    private let recordRating: ((SavedStudyID, UUID, RecallRating, Date) throws -> Void)?
    private let now: () -> Date

    init(session: ReviewSession, recordRating: ((SavedStudyID, UUID, RecallRating, Date) throws -> Void)? = nil, now: @escaping () -> Date = Date.init) {
        self.recordRating = recordRating
        self.now = now
        state = State(session: session)
    }

    @MainActor
    func send(_ action: Action) {
        guard !state.session.items.isEmpty else { return }
        switch action {
        case .reveal:
            guard !state.isComplete else { return }
            state.isAnswerVisible = true
        case .rate(let rating):
            guard state.isAnswerVisible, !state.isComplete, state.saveError == nil else { return }
            rate(rating)
        case .retry:
            guard let rating = state.pendingRating else { return }
            rate(rating)
        case .restart:
            guard state.session.origin != .due else { return }
            state.session.id = UUID()
            state.saveError = nil
            state.pendingRating = nil
            state.queue = PracticeQueue(ids: state.session.items.map(\.savedID))
            state.isAnswerVisible = false
            state.presentationRevision += 1
        }
    }

    private func rate(_ rating: RecallRating) {
        guard let item = state.currentItem else { return }
        if state.session.origin == .due {
            do {
                guard let recordRating else { throw ReviewSaveError.unavailable }
                let id = SavedStudyID(kind: state.session.kind == .words ? .word : .kanji, id: item.savedID)
                try recordRating(id, state.session.id, rating, now())
            } catch {
                state.pendingRating = rating
                state.saveError = "\(item.headword)'s review couldn't be saved. Try again or exit review."
                return
            }
        }
        state.saveError = nil
        state.pendingRating = nil
        state.queue.rate(rating)
        state.isAnswerVisible = false
        state.presentationRevision += 1
    }

    private enum ReviewSaveError: Error { case unavailable }

    struct State {
        var session: ReviewSession
        var queue: PracticeQueue
        var saveError: String?
        var pendingRating: RecallRating?
        var isAnswerVisible = false
        var presentationRevision = 0

        init(session: ReviewSession) {
            self.session = session
            queue = PracticeQueue(ids: session.items.map(\.savedID))
        }

        var currentItem: ReviewItem? {
            guard let id = queue.currentID else { return nil }
            return session.items.first { $0.savedID == id }
        }

        var remainingCount: Int { queue.remainingCount }
        var repeatAttempts: Int { queue.repeatAttempts }
        var distinctItemCount: Int { Set(session.items.map(\.savedID)).count }
        var isComplete: Bool { queue.currentID == nil }
    }

    enum Action {
        case reveal
        case rate(RecallRating)
        case retry
        case restart
    }
}
