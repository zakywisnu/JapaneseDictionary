import Foundation
import CryptoKit

public struct ExampleWordKey: Codable, Hashable {
    public let headword: String
    public let reading: String
    public let level: String

    public init(headword: String, reading: String, level: String) {
        self.headword = headword
        self.reading = reading
        self.level = level
    }
}

public struct ExampleReview: Codable, Hashable {
    public let reviewer: String
    public let reviewedOn: String
    public let verifiedSense: String
    public let japaneseSha256: String
    public let englishSha256: String
    public let changes: [String]
}

public struct ExampleSentence: Codable, Hashable {
    public let word: ExampleWordKey
    public let japaneseId: String
    public let englishId: String
    public let japanese: String
    public let english: String
    public let japaneseSource: String
    public let englishSource: String
    public let japaneseOwner: String?
    public let englishOwner: String?
    public let license: String
    public let sentenceReading: String?
    public let review: ExampleReview

    private enum CodingKeys: String, CodingKey {
        case word, japaneseId, englishId, japanese, english, japaneseSource, englishSource
        case japaneseOwner, englishOwner, license, sentenceReading, review
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Explicit null owners preserve absent attribution; missing fields indicate a malformed bundle.
        guard values.contains(.japaneseOwner), values.contains(.englishOwner), values.contains(.sentenceReading) else {
            throw ExampleResourceError.invalidMetadata
        }
        word = try values.decode(ExampleWordKey.self, forKey: .word)
        japaneseId = try values.decode(String.self, forKey: .japaneseId)
        englishId = try values.decode(String.self, forKey: .englishId)
        japanese = try values.decode(String.self, forKey: .japanese)
        english = try values.decode(String.self, forKey: .english)
        japaneseSource = try values.decode(String.self, forKey: .japaneseSource)
        englishSource = try values.decode(String.self, forKey: .englishSource)
        japaneseOwner = try values.decodeIfPresent(String.self, forKey: .japaneseOwner)
        englishOwner = try values.decodeIfPresent(String.self, forKey: .englishOwner)
        license = try values.decode(String.self, forKey: .license)
        sentenceReading = try values.decodeIfPresent(String.self, forKey: .sentenceReading)
        review = try values.decode(ExampleReview.self, forKey: .review)
    }
}

public enum ExampleResourceError: Error {
    case unsupportedVersion
    case duplicateWordKey
    case invalidMetadata
}

public struct ExampleRepository {
    private let examples: [ExampleWordKey: ExampleSentence]
    public let attributionText: String

    public init(data: Data, attributionText: String = "Tatoeba contributors. CC BY 2.0 FR.") throws {
        let resource = try JSONDecoder().decode(Resource.self, from: data)
        guard resource.formatVersion == 1 else { throw ExampleResourceError.unsupportedVersion }
        guard Self.validDate(resource.sourceSnapshot.downloadedOn), Self.validHash(resource.sourceSnapshot.vocabularySha256),
              resource.sourceSnapshot.sources.allSatisfy({ Self.validHash($0.sha256) && $0.bytes > 0 && Self.nonempty($0.file) && Self.nonempty($0.url) }) else {
            throw ExampleResourceError.invalidMetadata
        }
        var indexed: [ExampleWordKey: ExampleSentence] = [:]
        for example in resource.examples {
            guard Self.isValid(example) else { throw ExampleResourceError.invalidMetadata }
            guard indexed[example.word] == nil else { throw ExampleResourceError.duplicateWordKey }
            indexed[example.word] = example
        }
        examples = indexed
        let credits = resource.examples.map { example in
            "\(example.word.headword) (\(example.word.reading), \(example.word.level))\nJapanese: \(example.japaneseSource), owner: \(example.japaneseOwner ?? "not recorded")\nEnglish: \(example.englishSource), owner: \(example.englishOwner ?? "not recorded")\nLicense: \(example.license)\nReviewed by \(example.review.reviewer) on \(example.review.reviewedOn)\nChanges: \(example.review.changes.isEmpty ? "none" : example.review.changes.joined(separator: "; "))"
        }
        self.attributionText = ([attributionText] + credits).joined(separator: "\n\n")
    }

    private init(attributionText: String) {
        examples = [:]
        self.attributionText = attributionText
    }

    public func example(for key: ExampleWordKey) -> ExampleSentence? {
        examples[key]
    }

    public static func bundled() -> ExampleRepository { bundledRepository }

    private static let bundledRepository: ExampleRepository = {
        let bundle = Bundle(for: ResourceBundleMarker.self)
        let credits = bundle.url(forResource: "tatoeba-attribution", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            ?? "Example sentence credits couldn't be opened. No examples are displayed."
        guard let url = bundle.url(forResource: "examples-n5", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let repository = try? ExampleRepository(data: data, attributionText: credits) else {
            // Optional examples must never prevent opening a saved definition or review session.
            return ExampleRepository(attributionText: credits)
        }
        return repository
    }()

    private static func isValid(_ example: ExampleSentence) -> Bool {
        let strings = [example.word.headword, example.word.reading, example.japanese, example.english,
                       example.review.reviewer, example.review.verifiedSense]
        guard strings.allSatisfy(nonempty), example.word.level == "N5",
              ["CC BY 2.0 FR", "CC0"].contains(example.license), validDate(example.review.reviewedOn),
              validID(example.japaneseId), validID(example.englishId),
              example.japaneseSource == "https://tatoeba.org/en/sentences/show/\(example.japaneseId)",
              example.englishSource == "https://tatoeba.org/en/sentences/show/\(example.englishId)",
              example.review.japaneseSha256 == hash(example.japanese),
              example.review.englishSha256 == hash(example.english) else { return false }
        return example.sentenceReading.map(nonempty) ?? true
    }

    private static func nonempty(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) } && (UInt64(value) ?? 0) > 0
    }

    private static func validHash(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func validDate(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }

    private struct Resource: Decodable {
        let formatVersion: Int
        let sourceSnapshot: Snapshot
        let examples: [ExampleSentence]
    }

    private struct Snapshot: Decodable {
        let downloadedOn: String
        let vocabularySha256: String
        let sources: [Source]
    }

    private struct Source: Decodable {
        let file: String
        let url: String
        let bytes: Int
        let sha256: String
    }
}

private final class ResourceBundleMarker {}
