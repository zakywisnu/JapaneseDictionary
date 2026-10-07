import Foundation
import CryptoKit

public struct CatalogSnapshot {
    public let fingerprint: String
    public let wordCount: Int
    public let kanjiCount: Int

    // The caller supplies the exact Add next order; bundle UUIDs are regenerated.
    public init(words: [KotobaDataModel], kanjis: [KanjiDataModel]) {
        wordCount = words.count
        kanjiCount = kanjis.count
        let semanticWords = words.map { model -> BackupWord in
            var value = BackupWord(model)
            value.id = ""; value.dateAdded = nil; value.addedIndex = nil
            return value
        }
        let semanticKanjis = kanjis.map { model -> BackupKanji in
            var value = BackupKanji(model)
            value.id = ""; value.dateAdded = nil; value.addedIndex = nil
            return value
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let bytes = try! encoder.encode(SemanticCatalog(words: semanticWords, kanjis: semanticKanjis))
        fingerprint = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

private struct SemanticCatalog: Encodable {
    let words: [BackupWord]
    let kanjis: [BackupKanji]
}

public enum BackupError: LocalizedError {
    case tooLarge, corrupt, unsupportedVersion, foreignCatalog, invalid(String), multipleProgress

    public var errorDescription: String? {
        switch self {
        case .tooLarge: return "This backup exceeds the 20 MiB limit. Choose a smaller backup file."
        case .corrupt: return "This file is not a readable study backup. Choose another JSON backup."
        case .unsupportedVersion: return "This backup uses an unsupported format. Choose a version 1 backup."
        case .foreignCatalog: return "This backup uses a different dictionary order. Restore it with the matching app catalog."
        case .invalid(let field): return "This backup contains invalid \(field). Choose another backup."
        case .multipleProgress: return "The store contains multiple progress records. Resolve them before exporting."
        }
    }
}

public enum BackupValidator {
    public static let maximumBytes = 20 * 1024 * 1024

    public static func validate(_ data: Data, catalog: CatalogSnapshot) throws -> StudyBackup {
        guard data.count <= maximumBytes else { throw BackupError.tooLarge }
        let backup: StudyBackup
        do { backup = try JSONDecoder().decode(StudyBackup.self, from: data) }
        catch { throw BackupError.corrupt }
        try validate(backup, catalog: catalog)
        return backup
    }

    public static func validate(_ backup: StudyBackup, catalog: CatalogSnapshot) throws {
        guard backup.formatVersion == 1 else { throw BackupError.unsupportedVersion }
        guard backup.catalogFingerprint == catalog.fingerprint else { throw BackupError.foreignCatalog }
        try date(backup.createdAt)
        // Saved content requires its original Add next indexes and cumulative counters.
        guard backup.progress != nil || (backup.words.isEmpty && backup.kanjis.isEmpty && backup.reviews.isEmpty) else {
            throw BackupError.invalid("missing collection progress")
        }
        try unique(backup.words.map(\.id), field: "word IDs")
        try unique(backup.kanjis.map(\.id), field: "kanji IDs")
        try unique(backup.reviews.map { $0.id.key }, field: "review IDs")
        for word in backup.words {
            try index(word.addedIndex, count: catalog.wordCount, endAllowed: false)
            if let added = word.dateAdded { try date(added) }
        }
        for kanji in backup.kanjis {
            guard kanji.stroke >= 0 else { throw BackupError.invalid("stroke counts") }
            try index(kanji.addedIndex, count: catalog.kanjiCount, endAllowed: false)
            if let added = kanji.dateAdded { try date(added) }
        }
        if let progress = backup.progress {
            guard !progress.id.isEmpty, progress.kanjiProgress >= 0, progress.kotobaProgress >= 0 else { throw BackupError.invalid("progress counters") }
            try index(progress.kanjiIndex, count: catalog.kanjiCount, endAllowed: true)
            try index(progress.kotobaIndex, count: catalog.wordCount, endAllowed: true)
            try date(progress.lastKanjiUpdated); try date(progress.lastKotobaUpdated)
        }
        let words = Set(backup.words.map(\.id)), kanjis = Set(backup.kanjis.map(\.id))
        for review in backup.reviews {
            guard (review.id.kind == .word ? words : kanjis).contains(review.id.id) else { throw BackupError.invalid("orphan review records") }
            guard (0...4).contains(review.stage), review.sessionBaselineStage.map({ (0...4).contains($0) }) ?? true else { throw BackupError.invalid("review stages") }
            try date(review.dueDate); try date(review.lastReviewedAt)
        }
    }

    private static func unique(_ ids: [String], field: String) throws {
        guard ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count else { throw BackupError.invalid(field) }
    }

    private static func index(_ value: Int?, count: Int, endAllowed: Bool) throws {
        guard let value else { return }
        guard value >= 0, endAllowed ? value <= count : value < count else { throw BackupError.invalid("catalog indexes") }
    }

    private static func date(_ value: Date) throws {
        // Gregorian years 1–9998 leave room for a 30-day schedule calculation.
        let seconds = value.timeIntervalSince1970
        guard seconds.isFinite, seconds >= -62_135_596_800, seconds < 253_370_764_800 else { throw BackupError.invalid("dates") }
    }
}
