import Foundation
import SwiftData

public final class BackupRepository {
    private let store: StudyStore
    private let catalog: CatalogSnapshot
    private let recoveryURL: URL
    private let save: (ModelContext) throws -> Void
    private let writeRecovery: (Data, URL) throws -> Void

    public init(store: StudyStore, catalog: CatalogSnapshot, recoveryURL: URL, save: @escaping (ModelContext) throws -> Void = { try $0.save() }, writeRecovery: @escaping (Data, URL) throws -> Void = { data, url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }) {
        self.store = store
        self.catalog = catalog
        self.recoveryURL = recoveryURL
        self.save = save
        self.writeRecovery = writeRecovery
    }

    public func export(preferences: BackupPreferences) throws -> Data {
        let context = store.makeContext()
        let progress = try context.fetch(FetchDescriptor<WordsProgressModel>())
        guard progress.count <= 1 else { throw BackupError.multipleProgress }
        let backup = StudyBackup(createdAt: Date(), catalogFingerprint: catalog.fingerprint,
            words: try context.fetch(FetchDescriptor<KotobaDataModel>()).map(BackupWord.init).sorted { $0.id < $1.id },
            kanjis: try context.fetch(FetchDescriptor<KanjiDataModel>()).map(BackupKanji.init).sorted { $0.id < $1.id },
            progress: progress.first.map(BackupProgress.init),
            reviews: try context.fetch(FetchDescriptor<ReviewRecordModel>()).map(\.value).sorted { $0.id.key < $1.id.key },
            preferences: preferences)
        try BackupValidator.validate(backup, catalog: catalog)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        guard data.count <= BackupValidator.maximumBytes else { throw BackupError.tooLarge }
        return data
    }

    public func validate(_ data: Data) throws -> StudyBackup {
        try BackupValidator.validate(data, catalog: catalog)
    }

    @discardableResult
    public func restore(_ backup: StudyBackup, currentPreferences: BackupPreferences) throws -> URL {
        try BackupValidator.validate(backup, catalog: catalog)
        try writeRecovery(export(preferences: currentPreferences), recoveryURL)
        let context = store.makeContext()
        do {
            for model in try context.fetch(FetchDescriptor<ReviewRecordModel>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<KotobaDataModel>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<KanjiDataModel>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<WordsProgressModel>()) { context.delete(model) }
            for word in backup.words { context.insert(word.model) }
            for kanji in backup.kanjis { context.insert(kanji.model) }
            if let progress = backup.progress { context.insert(progress.model) }
            for review in backup.reviews { context.insert(ReviewRecordModel(record: review)) }
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
        store.refreshContext()
        return recoveryURL
    }
}
