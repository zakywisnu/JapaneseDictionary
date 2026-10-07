//
//  HomeKotobaViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import Observation
import SwiftUI
import DomainKit
import DataKit

@Observable
final class HomeKotobaViewModel {
    var state: State
    
    private let getKotobaDataUseCase: GetKotobaDataUseCase
    private let getAllKotobaUseCase: GetAllKotobaUseCase
    private let getWordsProgressUseCase: GetWordsProgressUseCase
    private let addKotobaUseCase: AddKotobaUseCase
    private let deleteKotobaUseCase: DeleteKotobaUseCase
    
    private let getDueReviewsUseCase: GetDueReviewsUseCase

    init(
        state: State = .init(),
        getKotobaDataUseCase: GetKotobaDataUseCase,
        getAllKotobaUseCase: GetAllKotobaUseCase,
        getWordsProgressUseCase: GetWordsProgressUseCase,
        addKotobaUseCase: AddKotobaUseCase,
        deleteKotobaUseCase: DeleteKotobaUseCase,
        getDueReviewsUseCase: GetDueReviewsUseCase
    ) {
        self.getDueReviewsUseCase = getDueReviewsUseCase
        self.state = state
        self.getKotobaDataUseCase = getKotobaDataUseCase
        self.getAllKotobaUseCase = getAllKotobaUseCase
        self.getWordsProgressUseCase = getWordsProgressUseCase
        self.addKotobaUseCase = addKotobaUseCase
        self.deleteKotobaUseCase = deleteKotobaUseCase
    }
    
    @MainActor
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            if state.allKotobas.isEmpty {
                fetchAllKotoba()
            }
            reload()
        case .didTapAdd:
            addKotoba()
            reload()
        case let .didTapDelete(id):
            guard let kotoba = state.currentKotobas.first(where: { $0.id == id }) else { return }
            deleteKotoba(kotoba)
            reload()
        case .retryDue:
            fetchDueReviews()
        case .didDismissError:
            state.errorMessage = nil
        }
    }
}

extension HomeKotobaViewModel {
    private func reload() {
        fetchDueReviews()
        fetchProgress()
        fetchCurrentKotoba()
    }
    
    private func fetchDueReviews() {
        state.dueLoadState = .loading
        do {
            state.dueItems = try getDueReviewsUseCase.execute(kind: .word, now: Date()).map { ReviewItem(saved: $0.item) }
            state.dueLoadState = .loaded
        } catch {
            state.dueItems = []
            state.dueLoadState = .failed
        }
    }

    private func fetchAllKotoba() {
        do {
            state.allKotobas = try getKotobaDataUseCase.execute()
                .mapToKotobas()
                .stableSorted(by: { $0.jlptLevel.rawValue > $1.jlptLevel.rawValue })
        } catch {
            state.loadState = .failed
        }
    }
    
    private func fetchProgress() {
        state.progress = try? getWordsProgressUseCase.execute().mapToDomain()
    }
    
    private func fetchCurrentKotoba() {
        do {
            let result = try getAllKotobaUseCase.execute().mapToKotobas()
            state.currentKotobas = result
                .filter { $0.dateAdded.map { Calendar.current.isDateInToday($0) } ?? false }
                .sorted(by: { ($0.addedIndex ?? 0) > ($1.addedIndex ?? 0) })
            state.loadState = state.allKotobas.isEmpty ? .failed : .loaded
        } catch {
            state.loadState = .failed
        }
    }
    
    private func deleteKotoba(_ kotoba: Kotoba) {
        do {
            try deleteKotobaUseCase.execute(kotoba: kotoba.asKotobaParam)
        } catch {
            state.errorMessage = "\(kotoba.kanji) couldn't be removed. Try again."
        }
    }
    
    private func addKotoba() {
        guard let progress = state.progress else {
            state.errorMessage = "Your progress couldn't be read, so no word was added. Try again."
            return
        }
        guard let (kotobaParam, progressParam) = validateParam(progress) else {
            state.hasFinished = true
            return
        }
        do {
            try addKotobaUseCase.execute(param: kotobaParam, progress: progressParam)
        } catch {
            state.errorMessage = "The next word couldn't be added. Try again."
        }
    }
    
    private func validateParam(_ progress: WordsProgress) -> (KotobaParam, WordsProgressParam)? {
        let (kotoba, progressIndex) = fetchNextKotoba()
        guard let kotoba else {
            return nil
        }
        
        let kotobaParam = KotobaParam(
            id: kotoba.id,
            kanji: kotoba.kanji,
            furigana: kotoba.furigana,
            english: kotoba.english,
            jlptLevel: .init(rawValue: kotoba.jlptLevel.rawValue) ?? .n5,
            dateAdded: Date(),
            addedIndex: progressIndex
        )
        let level: WordsProgressParam.Level = .init(rawValue: min(progress.getKotobaProgress, WordsProgressParam.Level(rawValue: kotoba.jlptLevel.rawValue)?.rawValue ?? "N5")) ?? .n5
        let progressParam: WordsProgressParam = .init(
            id: progress.id,
            kanjiProgress: progress.kanjiProgress,
            kotobaProgress: progress.kotobaProgress + 1,
            kanjiLevel: .init(rawValue: progress.kanjiLevel.rawValue) ?? .n5,
            kotobaLevel: level,
            lastKotobaUpdated: Date(),
            lastKanjiUpdated: progress.lastKanjiUpdated,
            kanjiIndex: progress.kanjiIndex,
            kotobaIndex: progressIndex + 1
        )
        
        return (kotobaParam, progressParam)
    }
    
    /// Skips words that were already added today, starting from the saved index.
    private func fetchNextKotoba() -> (Kotoba?, Int) {
        guard let progress = state.progress, progress.kotobaIndex < state.allKotobas.count else {
            return (nil, state.progress?.kotobaIndex ?? 0)
        }
        for index in progress.kotobaIndex..<state.allKotobas.count {
            let candidate = state.allKotobas[index]
            if !state.currentKotobas.contains(where: { $0.id == candidate.id }) {
                return (candidate, max(index, progress.kotobaIndex))
            }
        }
        return (nil, progress.kotobaIndex)
    }
}

extension HomeKotobaViewModel {
    struct State {
        var dueItems: [ReviewItem] = []
        var dueLoadState: TodayLoadState = .loading
        var progress: WordsProgress?
        var allKotobas: [Kotoba] = []
        var currentKotobas: [Kotoba] = []
        var loadState: TodayLoadState = .loading
        var hasFinished = false
        var errorMessage: String?
        
        var entries: [StudyEntry] { currentKotobas.map(\.studyEntry) }
        
        var nextLevel: String? {
            guard let index = progress?.kotobaIndex, index < allKotobas.count else { return nil }
            return allKotobas[index].jlptLevel.rawValue
        }
    }
    
    enum Action {
        case retryDue
        case onAppear
        case didTapAdd
        case didTapDelete(String)
        case didDismissError
    }
}
