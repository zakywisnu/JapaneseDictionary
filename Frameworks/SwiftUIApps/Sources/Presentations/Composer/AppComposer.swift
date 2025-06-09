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
    
    private init() {
        let context = Self.composeModelContext()
        let repository = Repository(
            kanjiRepository: StandardKanjiRepository(context: context.kanjiContext),
            kotobaRepository: StandardKotobaRepository(context: context.kotobaContext),
            vocabRepository: StandardVocabRepository(),
            wordsProgressRepository: StandardWordsProgressRepository(context: context.wordsProgressContext)
        )
        
        self.useCase = UseCase(
            getWordsProgressUseCase: DefaultGetWordsProgressUseCase(wordsProgressRepository: repository.wordsProgressRepository),
            updateWordsProgressUseCase: DefaultUpdateWordsProgressUseCase(wordsProgressRepository: repository.wordsProgressRepository),
            addKanjiUseCase: DefaultAddKanjiUseCase(kanjiRepository: repository.kanjiRepository, wordsProgressRepository: repository.wordsProgressRepository),
            deleteKanjiUseCase: DefaultDeleteKanjiUseCase(kanjiRepository: repository.kanjiRepository, wordsProgressRepository: repository.wordsProgressRepository),
            getAllKanjiUseCase: DefaultGetAllKanjiUseCase(repository: repository.kanjiRepository),
            getKanjiDetailUseCase: DefaultGetKanjiDetailUseCase(repository: repository.kanjiRepository),
            updateKanjiUseCase: DefaultUpdateKanjiUseCase(repository: repository.kanjiRepository),
            addKotobaUseCase: DefaultAddKotobaUseCase(kotobaRepository: repository.kotobaRepository, wordsProgressRepository: repository.wordsProgressRepository),
            deleteKotobaUseCase: DefaultDeleteKotobaUseCase(kotobaRepository: repository.kotobaRepository, wordsProgressRepository: repository.wordsProgressRepository),
            getAllKotobaUseCase: DefaultGetAllKotobaUseCase(repository: repository.kotobaRepository),
            getKotobaDetailUseCase: DefaultGetKotobaDetailUseCase(repository: repository.kotobaRepository),
            updateKotobaUseCase: DefaultUpdateKotobaUseCase(repository: repository.kotobaRepository),
            getKanjiDataUseCase: DefaultGetKanjiDataUseCase(repository: repository.vocabRepository),
            getKotobaDataUseCase: DefaultGetKotobaUseCase(repository: repository.vocabRepository)
        )
    }

    @ViewBuilder
    public func makeHomeView() -> some View {
        let viewModel = HomeViewModel()
        HomeView(viewModel: viewModel)
    }

    @ViewBuilder
    public func makeKanaView() -> some View {
        let viewModel = HomeKotobaViewModel(
            getKotobaDataUseCase: useCase.getKotobaDataUseCase,
            getAllKotobaUseCase: useCase.getAllKotobaUseCase,
            getWordsProgressUseCase: useCase.getWordsProgressUseCase,
            addKotobaUseCase: useCase.addKotobaUseCase,
            deleteKotobaUseCase: useCase.deleteKotobaUseCase
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
            deleteKanjiUseCase: useCase.deleteKanjiUseCase
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
}

extension AppComposer {
    private static func composeModelContext() -> AppModelContext {
        let schema = Schema([
            KanjiDataModel.self,
            KotobaDataModel.self,
            WordsProgressModel.self
        ])
        
        let storeURL = URL.applicationSupportDirectory.appending(path: "JapaneseDictionary.store")
        
//        // Delete existing store due to schema change
//        try? FileManager.default.removeItem(at: storeURL)
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: modelConfiguration)
            let context = ModelContext(container)
            context.autosaveEnabled = true
            
            print(storeURL)
            
            return .init(
                kanjiContext: context,
                kotobaContext: context,
                wordsProgressContext: context
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
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
