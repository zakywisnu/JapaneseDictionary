//
//  HomeKanjiViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 23/05/25.
//

import Observation
import SwiftUI
import DomainKit
import DataKit

@Observable
final class HomeKanjiViewModel {
    var state: State
    
    private let getKanjiDataUseCase: GetKanjiDataUseCase
    private let getAllKanjiUseCase: GetAllKanjiUseCase
    private let getWordsProgressUseCase: GetWordsProgressUseCase
    private let addKanjiUseCase: AddKanjiUseCase
    private let deleteKanjiUseCase: DeleteKanjiUseCase
    
    private let getDueReviewsUseCase: GetDueReviewsUseCase

    init(
        state: State = .init(),
        getKanjiDataUseCase: GetKanjiDataUseCase,
        getAllKanjiUseCase: GetAllKanjiUseCase,
        getWordsProgressUseCase: GetWordsProgressUseCase,
        addKanjiUseCase: AddKanjiUseCase,
        deleteKanjiUseCase: DeleteKanjiUseCase,
        getDueReviewsUseCase: GetDueReviewsUseCase
    ) {
        self.getDueReviewsUseCase = getDueReviewsUseCase
        self.state = state
        self.getKanjiDataUseCase = getKanjiDataUseCase
        self.getAllKanjiUseCase = getAllKanjiUseCase
        self.getWordsProgressUseCase = getWordsProgressUseCase
        self.addKanjiUseCase = addKanjiUseCase
        self.deleteKanjiUseCase = deleteKanjiUseCase
    }
    
    @MainActor
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            if state.allKanjis.isEmpty {
                fetchAllKanji()
            }
            reload()
        case .didTapAdd:
            addKanji()
            reload()
        case let .didTapDelete(id):
            guard let kanji = state.currentKanjis.first(where: { $0.id == id }) else { return }
            deleteKanji(kanji)
            reload()
        case .retryDue:
            fetchDueReviews()
        case .didDismissError:
            state.errorMessage = nil
        }
    }
}

extension HomeKanjiViewModel {
    private func reload() {
        fetchDueReviews()
        fetchProgress()
        fetchCurrentKanji()
    }
    
    private func fetchDueReviews() {
        state.dueLoadState = .loading
        do {
            state.dueItems = try getDueReviewsUseCase.execute(kind: .kanji, now: Date()).map { ReviewItem(saved: $0.item) }
            state.dueLoadState = .loaded
        } catch {
            state.dueItems = []
            state.dueLoadState = .failed
        }
    }

    private func fetchAllKanji() {
        do {
            state.allKanjis = try getKanjiDataUseCase.execute()
                .mapToDomain()
                .stableSorted(by: { $0.jlptLevel.rawValue > $1.jlptLevel.rawValue })
        } catch {
            state.loadState = .failed
        }
    }
    
    private func fetchProgress() {
        state.progress = try? getWordsProgressUseCase.execute().mapToDomain()
    }
    
    private func fetchCurrentKanji() {
        do {
            let result = try getAllKanjiUseCase.execute().mapToDomain()
            state.currentKanjis = result
                .filter { $0.dateAdded.map { Calendar.current.isDateInToday($0) } ?? false }
                .sorted(by: { ($0.addedIndex ?? 0) > ($1.addedIndex ?? 0) })
            state.loadState = state.allKanjis.isEmpty ? .failed : .loaded
        } catch {
            state.loadState = .failed
        }
    }
    
    private func deleteKanji(_ kanji: Kanji) {
        do {
            try deleteKanjiUseCase.execute(param: kanji.asKanjiParam)
        } catch {
            state.errorMessage = "\(kanji.kanji) couldn't be removed. Try again."
        }
    }
    
    private func addKanji() {
        guard let progress = state.progress else {
            state.errorMessage = "Your progress couldn't be read, so no kanji was added. Try again."
            return
        }
        guard let (kanjiParam, progressParam) = validateParam(progress) else {
            state.hasFinished = true
            return
        }
        do {
            try addKanjiUseCase.execute(param: kanjiParam, progress: progressParam)
        } catch {
            state.errorMessage = "The next kanji couldn't be added. Try again."
        }
    }
    
    private func validateParam(_ progress: WordsProgress) -> (KanjiParam, WordsProgressParam)? {
        let (kanji, progressIndex) = fetchNextKanji()
        guard let kanji else {
            return nil
        }
        
        let kanjiParam = KanjiParam(
            id: kanji.id,
            kanji: kanji.kanji,
            stroke: kanji.stroke,
            onyomi: kanji.onyomi,
            kunyomi: kanji.kunyomi,
            jlptLevel: .init(rawValue: kanji.jlptLevel.rawValue) ?? .n5,
            meanings: kanji.meanings,
            dateAdded: Date(),
            addedIndex: progressIndex
        )
        let level: WordsProgressParam.Level = .init(rawValue: min(progress.getKanjiProgress, WordsProgressParam.Level(rawValue: kanji.jlptLevel.rawValue)?.rawValue ?? "N5")) ?? .n5
        let progressParam: WordsProgressParam = .init(
            id: progress.id,
            kanjiProgress: progress.kanjiProgress + 1,
            kotobaProgress: progress.kotobaProgress,
            kanjiLevel: level,
            kotobaLevel: .init(rawValue: progress.kotobaLevel.rawValue) ?? .n5,
            lastKotobaUpdated: progress.lastKotobaUpdated,
            lastKanjiUpdated: Date(),
            kanjiIndex: progressIndex + 1,
            kotobaIndex: progress.kotobaIndex
        )
        
        return (kanjiParam, progressParam)
    }
    
    /// Skips kanji that were already added today, starting from the saved index.
    private func fetchNextKanji() -> (Kanji?, Int) {
        guard let progress = state.progress, progress.kanjiIndex < state.allKanjis.count else {
            return (nil, state.progress?.kanjiIndex ?? 0)
        }
        for index in progress.kanjiIndex..<state.allKanjis.count {
            let candidate = state.allKanjis[index]
            if !state.currentKanjis.contains(where: { $0.kanji == candidate.kanji }) {
                return (candidate, max(index, progress.kanjiIndex))
            }
        }
        return (nil, progress.kanjiIndex)
    }
}

extension HomeKanjiViewModel {
    struct State {
        var dueItems: [ReviewItem] = []
        var dueLoadState: TodayLoadState = .loading
        var progress: WordsProgress?
        var allKanjis: [Kanji] = []
        var currentKanjis: [Kanji] = []
        var loadState: TodayLoadState = .loading
        var hasFinished = false
        var errorMessage: String?
        
        var entries: [StudyEntry] { currentKanjis.map(\.studyEntry) }
        
        var nextLevel: String? {
            guard let index = progress?.kanjiIndex, index < allKanjis.count else { return nil }
            return allKanjis[index].jlptLevel.rawValue
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
