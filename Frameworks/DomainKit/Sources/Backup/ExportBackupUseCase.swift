import Foundation
import DataKit

public struct ExportBackupUseCase {
    private let repository: BackupRepository
    private let defaults: UserDefaults

    public init(repository: BackupRepository, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
    }

    public func execute() throws -> Data {
        try repository.export(preferences: BackupPreferences.read(from: defaults))
    }
}

extension BackupPreferences {
    static func read(from defaults: UserDefaults) -> BackupPreferences {
        .init(todayKind: BackupStudyKind(rawValue: defaults.string(forKey: "todayStudyKind") ?? "") ?? .words,
              collectionKind: BackupStudyKind(rawValue: defaults.string(forKey: "collectionStudyKind") ?? "") ?? .words)
    }
}

public struct PrepareBackupUseCase {
    private let repository: BackupRepository
    public init(repository: BackupRepository) { self.repository = repository }
    public func execute(_ data: Data) throws -> StudyBackup { try repository.validate(data) }
}
