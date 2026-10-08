import Foundation
import SwiftData

@Model
public final class StudyListMembershipModel {
    @Attribute(.unique) public var key: String
    public var listID: String
    public var wordID: String

    public init(listID: String, wordID: String) {
        self.listID = listID
        self.wordID = wordID
        key = Self.membershipKey(listID: listID, wordID: wordID)
    }

    public static func membershipKey(listID: String, wordID: String) -> String {
        "\(listID.utf8.count):\(listID)\(wordID.utf8.count):\(wordID)"
    }
}
