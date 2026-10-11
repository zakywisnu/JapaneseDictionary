import DataKit

public enum SentenceOrderPolicy {
    public static func matches(_ ids: [String], tokens: [PracticeToken], acceptedOrders: [[String]]) -> Bool {
        let uniqueIDs = Set(tokens.map(\.id))
        guard !tokens.isEmpty, uniqueIDs.count == tokens.count,
              ids.count == tokens.count, Set(ids) == uniqueIDs else { return false }
        let text = Dictionary(uniqueKeysWithValues: tokens.map { ($0.id, $0.text) })
        let rendered = ids.compactMap { text[$0] }
        return acceptedOrders.contains { order in
            order.count == tokens.count && Set(order) == uniqueIDs && order.compactMap { text[$0] } == rendered
        }
    }
}
