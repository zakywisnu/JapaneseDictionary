import XCTest
import DataKit
@testable import SwiftUIApps

final class BackupViewModelTests: XCTestCase {
    @MainActor
    func testImportOnlyPreviewsAndCancelNeverRestores() async {
        var restores = 0
        let backup = fixture()
        let model = BackupViewModel(export: { Data() }, prepare: { _ in backup }, restore: { _ in restores += 1; return URL(fileURLWithPath: "/tmp/recovery.json") })
        await model.send(.prepare(Data()))
        XCTAssertEqual(model.state.preview, backup)
        XCTAssertEqual(restores, 0)
        await model.send(.cancelPreview)
        await model.send(.confirmRestore)
        XCTAssertNil(model.state.preview)
        XCTAssertEqual(restores, 0)
    }

    @MainActor
    func testMalformedImportDoesNotApplyOrKeepOldPreview() async {
        var restores = 0
        let model = BackupViewModel(export: { Data() }, prepare: { _ in throw BackupError.corrupt }, restore: { _ in restores += 1; return URL(fileURLWithPath: "/tmp/recovery.json") })
        await model.send(.prepare(Data("invalid".utf8)))
        XCTAssertNil(model.state.preview)
        XCTAssertNotNil(model.state.errorMessage)
        await model.send(.confirmRestore)
        XCTAssertEqual(restores, 0)
    }

    @MainActor
    func testRestoreFailureRetainsPreviewThenExplicitRetryNotifiesSuccessOnce() async {
        var restores = 0
        var successes: [URL] = []
        var fail = true
        let backup = fixture()
        let recovery = URL(fileURLWithPath: "/tmp/recovery.json")
        let model = BackupViewModel(export: { Data() }, prepare: { _ in backup }, restore: { _ in
            restores += 1
            if fail { throw NSError(domain: "save", code: 1) }
            return recovery
        }, didRestore: { successes.append($0) }, availableRecoveryBackup: { recovery })
        await model.send(.prepare(Data()))
        await model.send(.confirmRestore)
        XCTAssertEqual(model.state.preview, backup)
        XCTAssertNotNil(model.state.errorMessage)
        XCTAssertTrue(successes.isEmpty)
        XCTAssertEqual(model.state.recoveryURL, recovery)
        fail = false
        await model.send(.confirmRestore)
        await model.send(.confirmRestore)
        XCTAssertEqual(restores, 2)
        XCTAssertEqual(successes, [recovery])
        XCTAssertNil(model.state.preview)
        XCTAssertEqual(model.state.recoveryURL, recovery)
    }

    @MainActor
    func testExportFailureCanBeRetriedAndFileCancellationHasNoError() async {
        var fail = true
        let model = BackupViewModel(export: {
            if fail { throw NSError(domain: "read", code: 1) }
            return Data("backup".utf8)
        }, prepare: { _ in self.fixture() }, restore: { _ in URL(fileURLWithPath: "/tmp/recovery.json") })
        await model.send(.export)
        XCTAssertNil(model.state.exportData)
        XCTAssertNotNil(model.state.errorMessage)
        fail = false
        await model.send(.export)
        XCTAssertEqual(model.state.exportData, Data("backup".utf8))
        await model.send(.exportFinished(.failure(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))))
        XCTAssertNil(model.state.errorMessage)
    }

    private func fixture() -> StudyBackup {
        StudyBackup(createdAt: Date(timeIntervalSince1970: 1_000), catalogFingerprint: "test", words: [], kanjis: [], progress: nil, reviews: [], preferences: .init())
    }
}
