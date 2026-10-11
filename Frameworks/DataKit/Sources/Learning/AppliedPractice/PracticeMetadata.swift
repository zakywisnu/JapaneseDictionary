import Foundation
import CryptoKit

public struct PracticeToken: Codable, Hashable {
    public var id: String
    public var text: String
    public init(id: String, text: String) { self.id = id; self.text = text }
}
public struct PracticeContentReview: Codable, Hashable {
    public var reviewer: String
    public var date: String
    public var contentHash: String
    public var method: String
    public init(reviewer: String, date: String, contentHash: String, method: String) {
        self.reviewer = reviewer; self.date = date; self.contentHash = contentHash; self.method = method
    }
}
public struct PracticeMetadata: Codable, Hashable {
    public var schemaVersion: Int
    public var activityKind: String
    public var topicID: String
    public var stimulus: String?
    public var suppliedReading: String?
    public var translation: String?
    public var tokens: [PracticeToken]
    public var acceptedOrders: [[String]]
    public var source: String
    public var review: PracticeContentReview?
    public var assisted: Bool
    public init(schemaVersion: Int = 1, activityKind: String, topicID: String, stimulus: String? = nil, suppliedReading: String? = nil, translation: String? = nil, tokens: [PracticeToken] = [], acceptedOrders: [[String]] = [], source: String, review: PracticeContentReview? = nil, assisted: Bool = false) {
        self.schemaVersion = schemaVersion; self.activityKind = activityKind; self.topicID = topicID
        self.stimulus = stimulus; self.suppliedReading = suppliedReading; self.translation = translation
        self.tokens = tokens; self.acceptedOrders = acceptedOrders; self.source = source; self.review = review; self.assisted = assisted
    }
    public var computedContentHash: String { var copy = self; copy.review = nil; return practiceHash(copy) }
}
func practiceHash<T: Encodable>(_ value: T) -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    return SHA256.hash(data: (try? encoder.encode(value)) ?? Data()).map { String(format: "%02x", $0) }.joined()
}
