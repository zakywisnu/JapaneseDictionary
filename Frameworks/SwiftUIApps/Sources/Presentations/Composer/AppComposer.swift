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
    let backupRestoreStatus = BackupRestoreStatus()
    private var backupCatalog: CatalogSnapshot?
    private var backupRepository: BackupRepository?
    private let getDueReviews: GetDueReviewsUseCase
    private let recordReview: RecordReviewUseCase
    let examples = ExampleRepository.bundled()
    
    private init() {
        do { store = try StudyStore() }
        catch { fatalError("Failed to create study store: \(error)") }
        let reviewRepository = StandardReviewRepository(store: store)
        getDueReviews = DefaultGetDueReviewsUseCase(repository: reviewRepository)
        recordReview = DefaultRecordReviewUseCase(repository: reviewRepository)
        let repository = Repository(
            kanjiRepository: StandardKanjiRepository(store: store),
            kotobaRepository: StandardKotobaRepository(store: store),
            vocabRepository: StandardVocabRepository(),
            wordsProgressRepository: StandardWordsProgressRepository(store: store)
        )
        
        self.useCase = UseCase(
            getWordsProgressUseCase: DefaultGetWordsProgressUseCase(wordsProgressRepository: repository.wordsProgressRepository),
            updateWordsProgressUseCase: DefaultUpdateWordsProgressUseCase(wordsProgressRepository: repository.wordsProgressRepository),
            addKanjiUseCase: DefaultAddKanjiUseCase(kanjiRepository: repository.kanjiRepository, wordsProgressRepository: repository.wordsProgressRepository),
            deleteKanjiUseCase: DefaultDeleteKanjiUseCase(mutationRepository: StandardStudyMutationRepository(store: store)),
            getAllKanjiUseCase: DefaultGetAllKanjiUseCase(repository: repository.kanjiRepository),
            getKanjiDetailUseCase: DefaultGetKanjiDetailUseCase(repository: repository.kanjiRepository),
            updateKanjiUseCase: DefaultUpdateKanjiUseCase(repository: repository.kanjiRepository),
            addKotobaUseCase: DefaultAddKotobaUseCase(kotobaRepository: repository.kotobaRepository, wordsProgressRepository: repository.wordsProgressRepository),
            deleteKotobaUseCase: DefaultDeleteKotobaUseCase(mutationRepository: StandardStudyMutationRepository(store: store)),
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
            let catalog = try composeBackupCatalog()
            return try await Task.detached(priority: .userInitiated) {
                try BackupValidator.validate(data, catalog: catalog)
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
        let vocabulary = StandardVocabRepository()
        let words = try vocabulary.fetchKotobaData().stableSorted { $0.jlptLevel.rawValue > $1.jlptLevel.rawValue }
        let kanjis = try vocabulary.fetchKanjiWanikaniData().stableSorted { $0.jlptLevel.rawValue > $1.jlptLevel.rawValue }
        let catalog = CatalogSnapshot(words: words, kanjis: kanjis)
        backupCatalog = catalog
        return catalog
    }

    private func composeBackupRepository() throws -> BackupRepository {
        if let backupRepository { return backupRepository }
        let recovery = URL.applicationSupportDirectory.appending(path: "Backups/kotoba-recovery.json")
        let repository = try BackupRepository(store: store, catalog: composeBackupCatalog(), recoveryURL: recovery)
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
