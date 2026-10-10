import Foundation
import SwiftData

public struct StudyList: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let createdAt: Date
    public let wordCount: Int
    public let sourceKey: String?
    public var itemCount: Int { wordCount }

    public init(id: String, name: String, createdAt: Date, wordCount: Int, sourceKey: String? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.wordCount = wordCount
        self.sourceKey = sourceKey
    }
}

@Model
public final class StudyListModel {
    @Attribute(.unique) public var id: String
    public var name: String
    public var normalizedName: String
    public var createdAt: Date
    @Attribute(.unique) public var sourceKey: String?

    public init(id: String, name: String, createdAt: Date, sourceKey: String? = nil) {
        self.id = id
        self.name = name
        normalizedName = Self.normalize(name)
        self.createdAt = createdAt
        self.sourceKey = sourceKey
    }

    public static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    public func value(wordCount: Int = 0) -> StudyList {
        StudyList(id: id, name: name, createdAt: createdAt, wordCount: wordCount, sourceKey: sourceKey)
    }
}
