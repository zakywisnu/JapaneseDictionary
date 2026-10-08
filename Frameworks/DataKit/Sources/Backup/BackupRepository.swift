import Foundation
import SwiftData

public final class BackupRepository {
    private let store: StudyStore
    private let catalog: CatalogSnapshot
    private let recoveryURL: URL
    private let save: (ModelContext) throws -> Void
    private let prepare: () throws -> Void
    private let legacyConverter: ((StudyBackup) throws -> StudyBackup)?
    private let writeRecovery: (Data, URL) throws -> Void

    public init(store: StudyStore, catalog: CatalogSnapshot, recoveryURL: URL, prepare: @escaping () throws -> Void = {}, legacyConverter: ((StudyBackup) throws -> StudyBackup)? = nil, save: @escaping (ModelContext) throws -> Void = { try $0.save() }, writeRecovery: @escaping (Data, URL) throws -> Void = { data, url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }) {
        self.prepare = prepare
        self.legacyConverter = legacyConverter
        self.store = store
        self.catalog = catalog
        self.recoveryURL = recoveryURL
        self.save = save
        self.writeRecovery = writeRecovery
    }

    public func export(preferences: BackupPreferences) throws -> Data {
        try prepare()
        let context = store.makeContext()
        let progress = try context.fetch(FetchDescriptor<WordsProgressModel>())
        guard progress.count <= 1 else { throw BackupError.multipleProgress }
        let goals = try context.fetch(FetchDescriptor<DailyGoalSettingsModel>())
        guard goals.count <= 1, goals.first.map({ $0.id == DailyGoalSettingsModel.singletonID }) ?? true else { throw BackupError.invalid("daily goal settings") }
        let lists = try context.fetch(FetchDescriptor<StudyListModel>()).map { BackupStudyList(id: $0.id, name: $0.name, createdAt: $0.createdAt) }.sorted { $0.id < $1.id }
        let memberships = try context.fetch(FetchDescriptor<StudyListMembershipModel>()).map { BackupListMembership(listID: $0.listID, wordID: $0.wordID) }.sorted { $0.key < $1.key }
        let activities = try context.fetch(FetchDescriptor<PracticeActivityModel>()).map(\.value).sorted { $0.key < $1.key }
        let target: Int? = goals.isEmpty ? 10 : goals[0].target
        let backup = StudyBackup(formatVersion: catalog.version == 2 ? 3 : catalog.version, createdAt: Date(), catalogFingerprint: catalog.fingerprint,
            words: try context.fetch(FetchDescriptor<KotobaDataModel>()).map(BackupWord.init).sorted { $0.id < $1.id },
            kanjis: try context.fetch(FetchDescriptor<KanjiDataModel>()).map(BackupKanji.init).sorted { $0.id < $1.id },
            progress: progress.first.map(BackupProgress.init),
            reviews: try context.fetch(FetchDescriptor<ReviewRecordModel>()).map(\.value).sorted { $0.id.key < $1.id.key },
            preferences: preferences, lists: lists, memberships: memberships, dailyGoal: target, activities: activities)
        try BackupValidator.validate(backup, catalog: catalog)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        guard data.count <= BackupValidator.maximumBytes else { throw BackupError.tooLarge }
        return data
    }

    public func validate(_ data: Data) throws -> StudyBackup {
        guard data.count <= BackupValidator.maximumBytes else { throw BackupError.tooLarge }
        let backup: StudyBackup
        do { backup = try JSONDecoder().decode(StudyBackup.self, from: data) }
        catch { throw BackupError.corrupt }
        return try normalized(backup)
    }

    public func validate(_ backup: StudyBackup) throws -> StudyBackup {
        try normalized(backup)
    }

    private func normalized(_ backup: StudyBackup) throws -> StudyBackup {
        if catalog.version == 2 && backup.formatVersion == 1, let legacyConverter {
            let converted = try legacyConverter(backup)
            try BackupValidator.validate(converted, catalog: catalog)
            return converted
        }
        try BackupValidator.validate(backup, catalog: catalog)
        return backup
    }

    @discardableResult
    public func restore(_ backup: StudyBackup, currentPreferences: BackupPreferences) throws -> URL {
        try prepare()
        let backup = try normalized(backup)
        try writeRecovery(export(preferences: currentPreferences), recoveryURL)
        let context = store.makeContext()
        do {
            for model in try context.fetch(FetchDescriptor<StudyListMembershipModel>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<StudyListModel>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<DailyGoalSettingsModel>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<PracticeActivityModel>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<ReviewRecordModel>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<KotobaDataModel>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<KanjiDataModel>()) { context.delete(model) }
            for model in try context.fetch(FetchDescriptor<WordsProgressModel>()) { context.delete(model) }
            for word in backup.words { context.insert(word.model) }
            for kanji in backup.kanjis { context.insert(kanji.model) }
            if let progress = backup.progress { context.insert(progress.model) }
            for review in backup.reviews { context.insert(ReviewRecordModel(record: review)) }
            for list in backup.lists { context.insert(StudyListModel(id: list.id, name: list.name, createdAt: list.createdAt)) }
            for member in backup.memberships { context.insert(StudyListMembershipModel(listID: member.listID, wordID: member.wordID)) }
            context.insert(DailyGoalSettingsModel(settings: .init(target: backup.dailyGoal)))
            for activity in backup.activities { context.insert(PracticeActivityModel(activity: activity)) }
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
        store.refreshContext()
        return recoveryURL
    }
}
