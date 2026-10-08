import Foundation
import SwiftData

public final class CatalogMigration {
    private let store: StudyStore
    private let preferences: () -> BackupPreferences
    private let vocabulary: VocabularyCatalogRepository
    private let legacyWords: [KotobaDataModel]
    private let recoveryURL: URL
    private let save: (ModelContext) throws -> Void
    private let writeRecovery: (Data, URL) throws -> Void
    public let legacySnapshot: CatalogSnapshot
    public let currentSnapshot: CatalogSnapshot
    private let indexes: [String: Int]

    public init(store: StudyStore, vocabulary: VocabularyCatalogRepository, legacyWords: [KotobaDataModel],
                kanjis: [KanjiDataModel], recoveryURL: URL,
                preferences: @escaping () -> BackupPreferences = { .init() },
                save: @escaping (ModelContext) throws -> Void = { try $0.save() },
                writeRecovery: @escaping (Data, URL) throws -> Void = { data, url in
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: url, options: .atomic)
                }) {
        self.preferences = preferences
        self.store = store; self.vocabulary = vocabulary; self.legacyWords = legacyWords
        self.recoveryURL = recoveryURL; self.save = save; self.writeRecovery = writeRecovery
        legacySnapshot = CatalogSnapshot(words: legacyWords, kanjis: kanjis)
        let words = vocabulary.catalog.entries.map { entry in
            KotobaDataModel(id: entry.id, kanji: entry.headword, furigana: entry.reading,
                            english: entry.studyMeanings.map { ArrayString(value: $0) },
                            jlptLevel: .init(rawValue: entry.level)!, dateAdded: nil, addedIndex: nil, catalogID: entry.id)
        }
        currentSnapshot = CatalogSnapshot(words: words, kanjis: kanjis, version: 2)
        indexes = Dictionary(uniqueKeysWithValues: vocabulary.catalog.entries.enumerated().map { ($0.element.id, $0.offset) })
    }

    public func ensureCurrent() throws {
        let context = store.makeContext()
        let progressRows = try context.fetch(FetchDescriptor<WordsProgressModel>())
        guard progressRows.count <= 1 else { throw BackupError.multipleProgress }
        guard let progress = progressRows.first else {
            guard try context.fetch(FetchDescriptor<KotobaDataModel>()).isEmpty,
                  try context.fetch(FetchDescriptor<KanjiDataModel>()).isEmpty else {
                throw BackupError.invalid("missing collection progress")
            }
            return
        }
        if progress.catalogVersion == 2 { return }
        guard progress.catalogVersion == nil || progress.catalogVersion == 1 else { throw BackupError.unsupportedVersion }
        guard vocabulary.catalog.legacyMap.count == legacyWords.count else { throw BackupError.invalid("legacy vocabulary mapping") }
        let original = try BackupRepository(store: store, catalog: legacySnapshot, recoveryURL: recoveryURL).export(preferences: preferences())
        let converted = try prepareLegacyBackup(JSONDecoder().decode(StudyBackup.self, from: original))
        try writeRecovery(original, recoveryURL)
        do {
            let saved = try context.fetch(FetchDescriptor<KotobaDataModel>())
            let mapped = Dictionary(uniqueKeysWithValues: converted.words.map { ($0.id, $0) })
            for word in saved {
                guard let convertedWord = mapped[word.id] else { throw BackupError.invalid("migration word identity") }
                word.catalogID = convertedWord.catalogID
                word.addedIndex = convertedWord.addedIndex
            }
            progress.catalogVersion = 2
            progress.kotobaIndex = converted.progress!.kotobaIndex
            progress.kotobaLevel = converted.progress!.kotobaLevel
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
        store.refreshContext()
    }

    public func prepareLegacyBackup(_ original: StudyBackup) throws -> StudyBackup {
        try BackupValidator.validate(original, catalog: legacySnapshot)
        guard vocabulary.catalog.legacyMap.count == legacyWords.count else { throw BackupError.invalid("legacy vocabulary mapping") }
        var result = original
        result.formatVersion = 2
        result.catalogFingerprint = currentSnapshot.fingerprint
        result.words = original.words.map { word in
            var mapped = word
            let identity = mappedIdentity(for: word)
            mapped.catalogID = identity
            mapped.addedIndex = identity.flatMap { indexes[$0] }
            return mapped
        }
        if var progress = result.progress {
            let collected = Set(result.words.compactMap(\.catalogID))
            let next = vocabulary.catalog.entries.firstIndex { !collected.contains($0.id) } ?? vocabulary.catalog.entries.count
            progress.catalogVersion = 2
            progress.kotobaIndex = next
            if next < vocabulary.catalog.entries.count {
                progress.kotobaLevel = .init(rawValue: vocabulary.catalog.entries[next].level)!
            }
            result.progress = progress
        }
        try BackupValidator.validate(result, catalog: currentSnapshot)
        return result
    }

    private func mappedIdentity(for word: BackupWord) -> String? {
        // Trust a legacy slot only when its saved study context still matches that slot.
        if let index = word.addedIndex, legacyWords.indices.contains(index) {
            let legacy = legacyWords[index]
            if legacy.kanji == word.kanji && legacy.furigana == word.furigana &&
               legacy.english.map(\.value) == word.english {
                return vocabulary.catalog.legacyMap[index]
            }
        }
        return vocabulary.word(headword: word.kanji, reading: word.furigana, meanings: word.english)?.id
    }
}

public final class VocabularyUpgradeService {
    private let store: StudyStore
    private var cached: CatalogMigration?
    private let lock = NSRecursiveLock()

    public init(store: StudyStore) { self.store = store }

    public func migration() throws -> CatalogMigration {
        lock.lock(); defer { lock.unlock() }
        if let cached { return cached }
        let repository = StandardVocabRepository()
        let words = try repository.fetchLegacyKotobaData().enumerated().sorted {
            if $0.element.jlptLevel != $1.element.jlptLevel { return $0.element.jlptLevel.rawValue > $1.element.jlptLevel.rawValue }
            return $0.offset < $1.offset
        }.map(\.element)
        let kanjis = try repository.fetchKanjiWanikaniData().enumerated().sorted {
            if $0.element.jlptLevel != $1.element.jlptLevel { return $0.element.jlptLevel.rawValue > $1.element.jlptLevel.rawValue }
            return $0.offset < $1.offset
        }.map(\.element)
        let migration = try CatalogMigration(store: store, vocabulary: .bundled(), legacyWords: words, kanjis: kanjis,
            recoveryURL: URL.applicationSupportDirectory.appending(path: "Backups/vocabulary-v1-recovery.json"),
            preferences: {
                .init(todayKind: .init(rawValue: UserDefaults.standard.string(forKey: "todayStudyKind") ?? "") ?? .words,
                      collectionKind: .init(rawValue: UserDefaults.standard.string(forKey: "collectionStudyKind") ?? "") ?? .words)
            })
        cached = migration
        return migration
    }

    public func ensureCurrent() throws {
        lock.lock(); defer { lock.unlock() }
        try migration().ensureCurrent()
    }
}
