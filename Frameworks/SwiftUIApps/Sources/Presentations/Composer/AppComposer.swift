//
//  AppComposer.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import SwiftData
import SwiftUI
import DomainKit
import DataKit

public final class AppComposer {
    public static let shared = AppComposer()
    public let useCase: UseCase
    public let store: StudyStore
    private let vocabularyUpgrade: VocabularyUpgradeService
    let addSelectedWord: any AddSelectedWordUseCase
    let backupRestoreStatus = BackupRestoreStatus()
    private var backupCatalog: CatalogSnapshot?
    private var backupRepository: BackupRepository?
    private let getDueReviews: GetDueReviewsUseCase
    private let recordReview: RecordReviewUseCase
    let examples = ExampleRepository.bundled()
    
    private init() {
        do { store = try StudyStore() }
        catch { fatalError("Failed to create study store: \(error)") }
        let vocabularyUpgrade = VocabularyUpgradeService(store: store)
        self.vocabularyUpgrade = vocabularyUpgrade
        let wordAddition = StandardWordAdditionRepository(store: store, prepare: vocabularyUpgrade.ensureCurrent)
        addSelectedWord = DefaultAddSelectedWordUseCase(additionRepository: wordAddition)
        let reviewRepository = StandardReviewRepository(store: store)
        getDueReviews = DefaultGetDueReviewsUseCase(repository: reviewRepository)
        recordReview = DefaultRecordReviewUseCase(repository: reviewRepository)
        let repository = Repository(
            kanjiRepository: StandardKanjiRepository(store: store),
            kotobaRepository: StandardKotobaRepository(store: store, prepare: vocabularyUpgrade.ensureCurrent),
            vocabRepository: StandardVocabRepository(),
            wordsProgressRepository: StandardWordsProgressRepository(store: store, prepare: vocabularyUpgrade.ensureCurrent, catalogVersion: 2)
        )
        
        self.useCase = UseCase(
            getWordsProgressUseCase: DefaultGetWordsProgressUseCase(wordsProgressRepository: repository.wordsProgressRepository),
            updateWordsProgressUseCase: DefaultUpdateWordsProgressUseCase(wordsProgressRepository: repository.wordsProgressRepository),
            addKanjiUseCase: DefaultAddKanjiUseCase(kanjiRepository: repository.kanjiRepository, wordsProgressRepository: repository.wordsProgressRepository),
            deleteKanjiUseCase: DefaultDeleteKanjiUseCase(mutationRepository: StandardStudyMutationRepository(store: store, prepare: vocabularyUpgrade.ensureCurrent)),
            getAllKanjiUseCase: DefaultGetAllKanjiUseCase(repository: repository.kanjiRepository),
            getKanjiDetailUseCase: DefaultGetKanjiDetailUseCase(repository: repository.kanjiRepository),
            updateKanjiUseCase: DefaultUpdateKanjiUseCase(repository: repository.kanjiRepository),
            addKotobaUseCase: DefaultAddKotobaUseCase(additionRepository: wordAddition),
            deleteKotobaUseCase: DefaultDeleteKotobaUseCase(mutationRepository: StandardStudyMutationRepository(store: store, prepare: vocabularyUpgrade.ensureCurrent)),
            getAllKotobaUseCase: DefaultGetAllKotobaUseCase(repository: repository.kotobaRepository),
            getKotobaDetailUseCase: DefaultGetKotobaDetailUseCase(repository: repository.kotobaRepository),
            updateKotobaUseCase: DefaultUpdateKotobaUseCase(repository: repository.kotobaRepository),
            getKanjiDataUseCase: DefaultGetKanjiWaniKaniUseCase(repository: repository.vocabRepository),
            getKotobaDataUseCase: DefaultGetKotobaUseCase(repository: repository.vocabRepository)
        )
    }

    @ViewBuilder
    public func makeHomeView() -> some View {
        HomeView()
    }

    @ViewBuilder
    public func makeKanaView() -> some View {
        let viewModel = HomeKotobaViewModel(
            getKotobaDataUseCase: useCase.getKotobaDataUseCase,
            getAllKotobaUseCase: useCase.getAllKotobaUseCase,
            getWordsProgressUseCase: useCase.getWordsProgressUseCase,
            addKotobaUseCase: useCase.addKotobaUseCase,
            deleteKotobaUseCase: useCase.deleteKotobaUseCase,
            getDueReviewsUseCase: getDueReviews
        )
        HomeKotobaView(viewModel: viewModel)
    }
    
    @ViewBuilder
    public func makeKanjiView() -> some View {
        let viewModel = HomeKanjiViewModel(
            getKanjiDataUseCase: useCase.getKanjiDataUseCase,
            getAllKanjiUseCase: useCase.getAllKanjiUseCase,
            getWordsProgressUseCase: useCase.getWordsProgressUseCase,
            addKanjiUseCase: useCase.addKanjiUseCase,
            deleteKanjiUseCase: useCase.deleteKanjiUseCase,
            getDueReviewsUseCase: getDueReviews
        )
        HomeKanjiView(viewModel: viewModel)
    }

    @ViewBuilder
    public func makeDashboardView() -> some View {
        DashboardView()
    }
    
    @ViewBuilder
    public func makeOnboardingView() -> some View {
        let viewModel = AppsOnboardingViewModel()
        AppsOnboardingView(viewModel: viewModel)
    }

    public func makeBackupView() -> some View {
        let model = BackupViewModel(export: { [self] in
            try ExportBackupUseCase(repository: composeBackupRepository()).execute()
        }, prepare: { [self] data in
            let repository = try composeBackupRepository()
            return try await Task.detached(priority: .userInitiated) {
                try repository.validate(data)
            }.value
        }, restore: { [self] backup in
            try RestoreBackupUseCase(repository: composeBackupRepository()).execute(backup)
        }, didRestore: { [backupRestoreStatus] recovery in
            backupRestoreStatus.recoveryURL = recovery
        }, availableRecoveryBackup: {
            let recovery = URL.applicationSupportDirectory.appending(path: "Backups/kotoba-recovery.json")
            return FileManager.default.fileExists(atPath: recovery.path) ? recovery : nil
        })
        return BackupView(viewModel: model)
    }

    private func composeBackupCatalog() throws -> CatalogSnapshot {
        if let backupCatalog { return backupCatalog }
        try vocabularyUpgrade.ensureCurrent()
        let catalog = try vocabularyUpgrade.migration().currentSnapshot
        backupCatalog = catalog
        return catalog
    }

    private func composeBackupRepository() throws -> BackupRepository {
        if let backupRepository { return backupRepository }
        let recovery = URL.applicationSupportDirectory.appending(path: "Backups/kotoba-recovery.json")
        let migration = try vocabularyUpgrade.migration()
        let repository = try BackupRepository(store: store, catalog: composeBackupCatalog(), recoveryURL: recovery,
            prepare: vocabularyUpgrade.ensureCurrent, legacyConverter: migration.prepareLegacyBackup)
        backupRepository = repository
        return repository
    }

    public func makeReviewView(_ session: ReviewSession) -> some View {
        ReviewView(viewModel: ReviewViewModel(session: session, recordRating: { [recordReview] id, sessionID, rating, now in
            try recordReview.execute(id: id, sessionID: sessionID, rating: rating, now: now)
        }), examples: examples)
    }
}

extension AppComposer {
    public static func getProgressFromUserDefaults() -> WordsProgress? {
        guard let data = UserDefaults.standard.data(forKey: "wordsProgress") else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(WordsProgress.self, from: data)
    }
}

extension AppComposer {
    public struct AppModelContext {
        public let kanjiContext: ModelContext
        public let kotobaContext: ModelContext
        public let wordsProgressContext: ModelContext
    }
    
    public struct Repository {
        public let kanjiRepository: KanjiRepository
        public let kotobaRepository: KotobaRepository
        public let vocabRepository: VocabRepository
        public let wordsProgressRepository: WordsProgressRepository
    }
    
    public struct UseCase {
        public let getWordsProgressUseCase: GetWordsProgressUseCase
        public let updateWordsProgressUseCase: UpdateWordsProgressUseCase
        public let addKanjiUseCase: AddKanjiUseCase
        public let deleteKanjiUseCase: DeleteKanjiUseCase
        public let getAllKanjiUseCase: GetAllKanjiUseCase
        public let getKanjiDetailUseCase: GetKanjiDetailUseCase
        public let updateKanjiUseCase: UpdateKanjiUseCase
        public let addKotobaUseCase: AddKotobaUseCase
        public let deleteKotobaUseCase: DeleteKotobaUseCase
        public let getAllKotobaUseCase: GetAllKotobaUseCase
        public let getKotobaDetailUseCase: GetKotobaDetailUseCase
        public let updateKotobaUseCase: UpdateKotobaUseCase
        public let getKanjiDataUseCase: GetKanjiDataUseCase
        public let getKotobaDataUseCase: GetKotobaDataUseCase
    }
}
