import SwiftUI
import DataKit

extension AppComposer {
    func makeDifficultPracticeView() -> some View {
        DifficultPracticeView(viewModel: .init(load: { [self] in
            let repository = StandardReviewRepository(store: store)
            let items = try SavedStudyKind.allCases.flatMap { try repository.savedItems(kind: $0) }.map(ReviewItem.init(saved:))
            let lists = try studyLists.lists()
            var memberships: [String: Set<SavedStudyID>] = [:]
            for list in lists { memberships[list.id] = Set(try studyLists.items(listID: list.id).map(\.id)) }
            return .init(items: items, records: try StandardStudyRatingRepository(store: store).records(), lists: lists, memberships: memberships)
        }))
    }
}
