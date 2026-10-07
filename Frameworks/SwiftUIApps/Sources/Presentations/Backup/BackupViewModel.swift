import Foundation
import Observation
import DataKit

@Observable
final class BackupRestoreStatus {
    var recoveryURL: URL?
}

@Observable
final class BackupViewModel {
    private(set) var state = State()
    private let export: () throws -> Data
    private let prepare: (Data) async throws -> StudyBackup
    private let restore: (StudyBackup) throws -> URL
    private let didRestore: (URL) -> Void
    private let availableRecoveryBackup: () -> URL?

    init(export: @escaping () throws -> Data, prepare: @escaping (Data) async throws -> StudyBackup,
         restore: @escaping (StudyBackup) throws -> URL, didRestore: @escaping (URL) -> Void = { _ in },
         availableRecoveryBackup: @escaping () -> URL? = { nil }) {
        self.export = export
        self.prepare = prepare
        self.restore = restore
        self.didRestore = didRestore
        self.availableRecoveryBackup = availableRecoveryBackup
    }

    @MainActor
    func send(_ action: Action) async {
        guard !state.isBusy else { return }
        switch action {
        case .export:
            state.errorMessage = nil
            state.exportData = nil
            do { state.exportData = try export() }
            catch { state.errorMessage = "Your backup couldn't be created. Try exporting again. \(error.localizedDescription)" }
        case .exportFinished(let result):
            state.exportData = nil
            if case .failure(let error) = result, !Self.isCancellation(error) {
                state.errorMessage = "Your backup couldn't be saved. Choose a destination and try again."
            } else {
                state.errorMessage = nil
            }
        case .importFile(let result):
            switch result {
            case .success(let url):
                await prepareImport { try await Self.readImport(url) }
            case .failure(let error):
                if !Self.isCancellation(error) { state.errorMessage = "The backup file couldn't be opened. Choose another file and try again." }
            }
        case .prepare(let data):
            await prepareImport { data }
        case .cancelPreview:
            state.preview = nil
            state.errorMessage = nil
        case .confirmRestore:
            guard let backup = state.preview else { return }
            state.isBusy = true
            state.errorMessage = nil
            defer { state.isBusy = false }
            do {
                let recovery = try restore(backup)
                state.recoveryURL = recovery
                state.preview = nil
                didRestore(recovery)
            } catch {
                state.recoveryURL = availableRecoveryBackup()
                state.errorMessage = "The backup couldn't replace your collection. Your current collection is unchanged. Try again. \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func prepareImport(read: () async throws -> Data) async {
        state.preview = nil
        state.errorMessage = nil
        state.isBusy = true
        defer { state.isBusy = false }
        do {
            let data = try await read()
            state.preview = try await prepare(data)
        }
        catch { state.errorMessage = "The backup couldn't be opened. \(error.localizedDescription)" }
    }

    private static func readImport(_ url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var data = Data()
            while let chunk = try handle.read(upToCount: min(64 * 1024, BackupValidator.maximumBytes + 1 - data.count)), !chunk.isEmpty {
                data.append(chunk)
                guard data.count <= BackupValidator.maximumBytes else { throw BackupError.tooLarge }
            }
            return data
        }.value
    }

    private static func isCancellation(_ error: Error) -> Bool {
        let cocoa = error as NSError
        return cocoa.domain == NSCocoaErrorDomain && cocoa.code == NSUserCancelledError
    }

    struct State {
        var preview: StudyBackup?
        var exportData: Data?
        var recoveryURL: URL?
        var errorMessage: String?
        var isBusy = false
    }

    enum Action {
        case export
        case exportFinished(Result<URL, Error>)
        case importFile(Result<URL, Error>)
        case prepare(Data)
        case cancelPreview
        case confirmRestore
    }
}
