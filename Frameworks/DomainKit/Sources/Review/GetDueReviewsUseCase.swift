import Foundation
import DataKit

public struct DueReview: Hashable {
    public let item: SavedStudyItem
    public let dueDate: Date
    public init(item: SavedStudyItem, dueDate: Date) {
        self.item = item
        self.dueDate = dueDate
    }
}

public protocol GetDueReviewsUseCase {
    func execute(kind: SavedStudyKind, now: Date) throws -> [DueReview]
}

public struct DefaultGetDueReviewsUseCase: GetDueReviewsUseCase {
    private let repository: ReviewRepository
    public init(repository: ReviewRepository) { self.repository = repository }

    public func execute(kind: SavedStudyKind, now: Date) throws -> [DueReview] {
        let records = Dictionary(try repository.records().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return try repository.savedItems(kind: kind).compactMap { item in
            let record = records[item.id]
            let dueDate = record?.dueDate ?? item.dateAdded ?? .distantPast
            // Unrated items remain due even if the device clock predates their added date.
            guard record == nil || dueDate <= now else { return nil }
            return DueReview(item: item, dueDate: dueDate)
        }.sorted {
            if $0.dueDate != $1.dueDate { return $0.dueDate < $1.dueDate }
            return $0.item.id.key < $1.item.id.key
        }
    }
}
