import Foundation

public struct MemoryAidWord: Equatable, Sendable {
    public let id: String
    public let headword: String
    public let reading: String
    public let meanings: [String]
    public let level: String

    public init(id: String, headword: String, reading: String, meanings: [String], level: String) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.meanings = meanings
        self.level = level
    }
}

public struct MemoryAidSuggestion: Codable, Equatable, Sendable {
    public let explanation: String
    public let mnemonic: String

    public init(explanation: String, mnemonic: String) {
        self.explanation = explanation
        self.mnemonic = mnemonic
    }

    public func validated() throws -> MemoryAidSuggestion {
        let explanation = explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        let mnemonic = mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...600).contains(explanation.count), (1...600).contains(mnemonic.count) else {
            throw MemoryAidStorageError.invalidSuggestion
        }
        return .init(explanation: explanation, mnemonic: mnemonic)
    }
}

public enum MemoryAidStorageError: Error, Equatable {
    case missingWord
    case changedWord
    case invalidSuggestion
}
