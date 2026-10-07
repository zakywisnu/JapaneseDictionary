import Foundation
import DataKit

public extension Notification.Name {
    static let backupRestoreCompleted = Notification.Name("BackupRestoreCompleted")
}

public struct RestoreBackupUseCase {
    private let repository: BackupRepository
    private let defaults: UserDefaults
    private let notifications: NotificationCenter

    public init(repository: BackupRepository, defaults: UserDefaults = .standard, notifications: NotificationCenter = .default) {
        self.repository = repository
        self.defaults = defaults
        self.notifications = notifications
    }

    @discardableResult
    public func execute(_ backup: StudyBackup) throws -> URL {
        let shadowData: Data?
        if let progress = backup.progress {
            let shadow = WordsProgressParam(id: progress.id, kanjiProgress: progress.kanjiProgress, kotobaProgress: progress.kotobaProgress,
                kanjiLevel: .init(rawValue: progress.kanjiLevel.rawValue)!, kotobaLevel: .init(rawValue: progress.kotobaLevel.rawValue)!,
                lastKotobaUpdated: progress.lastKotobaUpdated, lastKanjiUpdated: progress.lastKanjiUpdated,
                kanjiIndex: progress.kanjiIndex, kotobaIndex: progress.kotobaIndex)
            shadowData = try JSONEncoder().encode(shadow)
        } else {
            shadowData = nil
        }
        let recovery = try repository.restore(backup, currentPreferences: BackupPreferences.read(from: defaults))
        defaults.set(backup.preferences.todayKind.rawValue, forKey: "todayStudyKind")
        defaults.set(backup.preferences.collectionKind.rawValue, forKey: "collectionStudyKind")
        defaults.set(true, forKey: "isOnboardingComplete")
        if let shadowData {
            defaults.set(shadowData, forKey: "wordsProgress")
        } else {
            defaults.removeObject(forKey: "wordsProgress")
        }
        notifications.post(name: .backupRestoreCompleted, object: nil)
        return recovery
    }
}
