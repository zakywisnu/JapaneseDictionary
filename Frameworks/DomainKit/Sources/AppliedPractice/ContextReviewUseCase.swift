import Foundation
import DataKit

public struct ContextReviewUseCase {
    private let contexts: [ReviewedContext]
    public init(contexts: [ReviewedContext]) { self.contexts = contexts }
    public func context(for key: ExampleWordKey, savedMeanings: [String], catalogID: String? = nil) -> ReviewedContext? {
        let meanings = Set(savedMeanings.map(Self.normalized))
        guard !meanings.isEmpty else { return nil }
        let matches = contexts.filter {
            $0.word == key && ($0.catalogID == nil || $0.catalogID == catalogID)
                && Set($0.verifiedMeanings.map(Self.normalized)) == meanings
        }
        return matches.count == 1 ? matches[0] : nil
    }
    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().precomposedStringWithCanonicalMapping
    }
}
