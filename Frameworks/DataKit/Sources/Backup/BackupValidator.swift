import Foundation
import CryptoKit

public struct CatalogSnapshot {
    public let fingerprint: String
    public let wordCount: Int
    public let kanjiCount: Int
    public let version: Int
    public let wordIdentities: [String?]

    // The caller supplies the exact Add next order; bundle UUIDs are regenerated.
    public init(words: [KotobaDataModel], kanjis: [KanjiDataModel], version: Int = 1) {
        self.version = version
        wordIdentities = words.map(\.catalogID)
        wordCount = words.count
        kanjiCount = kanjis.count
        let semanticWords = words.map { model -> BackupWord in
            var value = BackupWord(model)
            value.id = ""; value.dateAdded = nil; value.addedIndex = nil
            value.memoryAid = nil
            if version == 1 { value.catalogID = nil }
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
        case .unsupportedVersion: return "This backup uses an unsupported format. Choose a backup compatible with this vocabulary catalog."
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
        guard backup.formatVersion == catalog.version || (catalog.version == 2 && backup.formatVersion == 3) || [4, 5, 6].contains(backup.formatVersion) else { throw BackupError.unsupportedVersion }
        guard backup.catalogFingerprint == catalog.fingerprint else { throw BackupError.foreignCatalog }
        try date(backup.createdAt)
        if backup.formatVersion < 6 { guard backup.pathProgress.isEmpty else { throw BackupError.invalid("path data in an older backup format") } }
        guard backup.pathProgress.count <= 100 else { throw BackupError.invalid("path progress") }
        try unique(backup.pathProgress.map(\.pathID), field: "path identities")
        try backup.pathProgress.forEach(LearningPathValidator.validate)
        if backup.formatVersion < 5 {
            guard backup.attempts.isEmpty, backup.checkpoints.isEmpty, backup.reviewRatingEvents.isEmpty else { throw BackupError.invalid("exercise history in an older backup format") }
        }
        try ExerciseHistoryValidator.validate(attempts: backup.attempts, checkpoints: backup.checkpoints, reviewRatingEvents: backup.reviewRatingEvents)
        // Saved content requires its original Add next indexes and cumulative counters.
        guard backup.progress != nil || (backup.words.isEmpty && backup.kanjis.isEmpty && !backup.reviews.contains(where: { [.word, .kanji].contains($0.id.kind) })) else {
            throw BackupError.invalid("missing collection progress")
        }
        try unique(backup.lists.compactMap(\.sourceKey), field: "list source keys")
        guard backup.lists.allSatisfy({ $0.sourceKey == nil || ($0.sourceKey!.hasPrefix("passage:") && !String($0.sourceKey!.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.sourceKey!.count <= 256) }) else { throw BackupError.invalid("list source key") }
        try unique(backup.words.map(\.id), field: "word IDs")
        try unique(backup.kanjis.map(\.id), field: "kanji IDs")
        try unique(backup.reviews.map { $0.id.key }, field: "review IDs")
        if backup.formatVersion < 3 {
            guard backup.lists.isEmpty, backup.memberships.isEmpty, backup.activities.isEmpty, backup.dailyGoal == 10 else { throw BackupError.invalid("study data in an older backup format") }
        }
        if backup.formatVersion < 4 {
            guard backup.materials.isEmpty, backup.difficulties.isEmpty, backup.itemMemberships.isEmpty,
                  [.words, .kanji].contains(backup.preferences.todayKind), [.words, .kanji].contains(backup.preferences.collectionKind),
                  backup.reviews.allSatisfy({ [.word, .kanji].contains($0.id.kind) }),
                  backup.activities.allSatisfy({ [.word, .kanji].contains($0.studyID.kind) }) else { throw BackupError.invalid("expanded study data in an older backup format") }
        }
        try unique(backup.materials.map { SavedStudyID(kind: $0.kind, id: $0.id).key }, field: "material identities")
        try unique(backup.materials.compactMap { value in value.source.map { value.kind.rawValue + ":" + $0.provider + ":" + $0.sourceID } }, field: "material sources")
        let savedIDs = Set(backup.words.map { SavedStudyID(kind: .word, id: $0.id) } + backup.kanjis.map { SavedStudyID(kind: .kanji, id: $0.id) } + backup.materials.map { SavedStudyID(kind: $0.kind, id: $0.id) })
        for material in backup.materials {
            guard UUID(uuidString: material.id) != nil,
                  let checked = try? StudyMaterialValidator.validate(material), checked == material else { throw BackupError.invalid("study materials") }
            try date(material.createdAt); try date(material.updatedAt)
        }
        try unique(backup.difficulties.map { $0.id.key }, field: "difficult identities")
        for record in backup.difficulties {
            guard savedIDs.contains(record.id), record.missCount >= 0,
                  (record.missCount == 0 || record.lastMissDate != nil),
                  !record.sessionHadAgain || record.missCount > 0 else { throw BackupError.invalid("difficult records") }
            if let value = record.lastMissDate { try date(value) }
        }
        let migratedMembershipKeys = backup.memberships.map { StudyItemMembership(listID: $0.listID, id: .init(kind: .word, id: $0.wordID)).key }
        try unique(backup.itemMemberships.map(\.key) + migratedMembershipKeys, field: "mixed memberships")
        for member in backup.itemMemberships {
            guard backup.lists.contains(where: { $0.id == member.listID }), savedIDs.contains(member.id) else { throw BackupError.invalid("orphan mixed membership") }
        }
        guard backup.dailyGoal.map({ [5, 10, 20, 30].contains($0) }) ?? true else { throw BackupError.invalid("daily goal") }
        try unique(backup.lists.map(\.id), field: "study list IDs")
        try unique(backup.lists.map { StudyListModel.normalize($0.name) }, field: "study list names")
        try unique(backup.memberships.map(\.key), field: "list memberships")
        try unique(backup.activities.map(\.key), field: "practice activities")
        let listIDs = Set(backup.lists.map(\.id)), wordIDs = Set(backup.words.map(\.id))
        for list in backup.lists {
            guard !list.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  list.name == list.name.trimmingCharacters(in: .whitespacesAndNewlines), !list.name.isEmpty, list.name.count <= 60 else { throw BackupError.invalid("study list names") }
            try date(list.createdAt)
        }
        for member in backup.memberships {
            guard listIDs.contains(member.listID), wordIDs.contains(member.wordID) else { throw BackupError.invalid("orphan list membership") }
        }
        for activity in backup.activities { try validateActivity(activity) }
        for word in backup.words {
            if catalog.version == 2 {
                if let identity = word.catalogID {
                    guard let index = word.addedIndex, index >= 0, index < catalog.wordCount,
                          catalog.wordIdentities[index] == identity else { throw BackupError.invalid("word catalog anchors") }
                } else if word.addedIndex != nil { throw BackupError.invalid("retired word catalog anchors") }
            }
            if let advice = word.memoryAid {
                guard advice.explanation.count <= 600, advice.mnemonic.count <= 600,
                      (try? advice.validated()) != nil else { throw BackupError.invalid("memory suggestions") }
            }
            try index(word.addedIndex, count: catalog.wordCount, endAllowed: false)
            if let added = word.dateAdded { try date(added) }
        }
        for kanji in backup.kanjis {
            guard kanji.stroke >= 0 else { throw BackupError.invalid("stroke counts") }
            try index(kanji.addedIndex, count: catalog.kanjiCount, endAllowed: false)
            if let added = kanji.dateAdded { try date(added) }
        }
        if let progress = backup.progress {
            if catalog.version == 2 && progress.catalogVersion != 2 { throw BackupError.invalid("catalog version") }
            if catalog.version == 1 && progress.catalogVersion != nil && progress.catalogVersion != 1 {
                throw BackupError.invalid("legacy catalog version")
            }
            guard !progress.id.isEmpty, progress.kanjiProgress >= 0, progress.kotobaProgress >= 0 else { throw BackupError.invalid("progress counters") }
            try index(progress.kanjiIndex, count: catalog.kanjiCount, endAllowed: true)
            try index(progress.kotobaIndex, count: catalog.wordCount, endAllowed: true)
            try date(progress.lastKanjiUpdated); try date(progress.lastKotobaUpdated)
        }
        for review in backup.reviews {
            guard savedIDs.contains(review.id) else { throw BackupError.invalid("orphan review records") }
            guard (0...4).contains(review.stage), review.sessionBaselineStage.map({ (0...4).contains($0) }) ?? true else { throw BackupError.invalid("review stages") }
            try date(review.dueDate); try date(review.lastReviewedAt)
        }
    }

    public static func validateActivity(_ activity: PracticeActivity) throws {
        guard !activity.studyID.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              activity.key == PracticeActivity.activityKey(dayKey: activity.dayKey, studyID: activity.studyID) else { throw BackupError.invalid("practice identity") }
        let parts = activity.dayKey.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, activity.dayKey.count == 10,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]), (1...9998).contains(year) else { throw BackupError.invalid("practice day") }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let value = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.dateComponents([.year, .month, .day], from: value) == DateComponents(year: year, month: month, day: day),
              String(format: "%04d-%02d-%02d", year, month, day) == activity.dayKey else { throw BackupError.invalid("practice day") }
        try date(activity.completedAt)
    }

    private static func unique(_ ids: [String], field: String) throws {
        guard ids.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }), Set(ids).count == ids.count else { throw BackupError.invalid(field) }
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
