import XCTest
import SwiftData
import DataKit
@testable import DomainKit

final class BackupUseCaseTests: XCTestCase {
    func testFailedRestoreLeavesPreferencesShadowAndNotificationUnchanged() throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("words", forKey: "todayStudyKind")
        defaults.set("words", forKey: "collectionStudyKind")
        defaults.set(false, forKey: "isOnboardingComplete")
        let oldShadow = Data("old shadow".utf8)
        defaults.set(oldShadow, forKey: "wordsProgress")
        let store = try StudyStore(inMemory: true)
        let repository = BackupRepository(store: store, catalog: CatalogSnapshot(words: [], kanjis: []), recoveryURL: recoveryURL(), save: { _ in throw Failure.injected })
        var backup = try repository.validate(ExportBackupUseCase(repository: repository, defaults: defaults).execute())
        backup.preferences = .init(todayKind: .kanji, collectionKind: .kanji)
        let center = NotificationCenter()
        var notified = false
        let observer = center.addObserver(forName: .backupRestoreCompleted, object: nil, queue: nil) { _ in notified = true }
        defer { center.removeObserver(observer) }
        XCTAssertThrowsError(try RestoreBackupUseCase(repository: repository, defaults: defaults, notifications: center).execute(backup))
        XCTAssertEqual(defaults.string(forKey: "todayStudyKind"), "words")
        XCTAssertEqual(defaults.string(forKey: "collectionStudyKind"), "words")
        XCTAssertFalse(defaults.bool(forKey: "isOnboardingComplete"))
        XCTAssertEqual(defaults.data(forKey: "wordsProgress"), oldShadow)
        XCTAssertFalse(notified)
    }

    func testSuccessfulFreshRestoreClearsShadowAppliesPreferencesAndCompletesOnboarding() throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("stale".utf8), forKey: "wordsProgress")
        let store = try StudyStore(inMemory: true)
        let repository = BackupRepository(store: store, catalog: CatalogSnapshot(words: [], kanjis: []), recoveryURL: recoveryURL())
        var backup = try repository.validate(ExportBackupUseCase(repository: repository, defaults: defaults).execute())
        backup.preferences = .init(todayKind: .kanji, collectionKind: .words)
        let center = NotificationCenter()
        var notified = false
        let observer = center.addObserver(forName: .backupRestoreCompleted, object: nil, queue: nil) { _ in notified = true }
        defer { center.removeObserver(observer) }
        let recovery = try RestoreBackupUseCase(repository: repository, defaults: defaults, notifications: center).execute(backup)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovery.path))
        XCTAssertEqual(defaults.string(forKey: "todayStudyKind"), "kanji")
        XCTAssertEqual(defaults.string(forKey: "collectionStudyKind"), "words")
        XCTAssertTrue(defaults.bool(forKey: "isOnboardingComplete"))
        XCTAssertNil(defaults.data(forKey: "wordsProgress"))
        XCTAssertTrue(notified)
    }

    func testSuccessfulRestoreRegeneratesShadowFromExactCumulativeProgress() throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = try StudyStore(inMemory: true)
        let repository = BackupRepository(store: store, catalog: CatalogSnapshot(words: [], kanjis: []), recoveryURL: recoveryURL())
        var backup = try repository.validate(repository.export(preferences: .init()))
        let date = Date(timeIntervalSince1970: 1_700_000_000.125)
        backup.progress = BackupProgress(id: "progress", kanjiProgress: 42, kotobaProgress: 73, kanjiLevel: .n3, kotobaLevel: .n2, kanjiIndex: 0, kotobaIndex: 0, lastKotobaUpdated: date, lastKanjiUpdated: date)
        try RestoreBackupUseCase(repository: repository, defaults: defaults).execute(backup)
        let shadow = try JSONDecoder().decode(WordsProgressParam.self, from: XCTUnwrap(defaults.data(forKey: "wordsProgress")))
        XCTAssertEqual(shadow.kanjiProgress, 42)
        XCTAssertEqual(shadow.kotobaProgress, 73)
        XCTAssertEqual(shadow.kotobaLevel.rawValue, "N2")
        XCTAssertEqual(shadow.lastKotobaUpdated, date)
    }

    private enum Failure: Error { case injected }
    private func recoveryURL() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json") }
}
