//
//  HomeKanjiViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 23/05/25.
//

import Observation
import SwiftUI
import DomainKit
import ZeroDesignKit

@Observable
final class HomeKanjiViewModel {
    var state: State
    
    private let getKanjiDataUseCase: GetKanjiDataUseCase
    private let getAllKanjiUseCase: GetAllKanjiUseCase
    private let getWordsProgressUseCase: GetWordsProgressUseCase
    private let addKanjiUseCase: AddKanjiUseCase
    private let deleteKanjiUseCase: DeleteKanjiUseCase
    
    init(
        state: State = .init(),
        getKanjiDataUseCase: GetKanjiDataUseCase,
        getAllKanjiUseCase: GetAllKanjiUseCase,
        getWordsProgressUseCase: GetWordsProgressUseCase,
        addKanjiUseCase: AddKanjiUseCase,
        deleteKanjiUseCase: DeleteKanjiUseCase
    ) {
        self.state = state
        self.getKanjiDataUseCase = getKanjiDataUseCase
        self.getAllKanjiUseCase = getAllKanjiUseCase
        self.getWordsProgressUseCase = getWordsProgressUseCase
        self.addKanjiUseCase = addKanjiUseCase
        self.deleteKanjiUseCase = deleteKanjiUseCase
    }
    
    @MainActor
    func send(_ action: Action) async throws {
        switch action {
        case .onAppear:
            fetchProgress()
            fetchAllKanji()
            fetchCurrentKanji()
        case .didTapAddKanji:
            state.buttonState = .loading
            try await Task.sleep(for: .seconds(1))
            await addKanji()
            try await Task.sleep(for: .seconds(2))
            state.buttonState = .idle
            fetchProgress()
            fetchCurrentKanji()
        case let .didTapDeleteKanji(kanji):
            state.overlayLoading = true
            try await Task.sleep(for: .seconds(1))
            deleteKanji(kanji)
            fetchProgress()
            fetchCurrentKanji()
        }
    }
}

extension HomeKanjiViewModel {
    private func fetchAllKanji() {
        do {
            let result = try getKanjiDataUseCase.execute()
                .mapToDomain().sorted(by: { $0.jlptLevel.rawValue > $1.jlptLevel.rawValue })
            state.allKanjis = result
        } catch {
            print("all kanji error: ", error)
            print("all kanji error localized: ", error.localizedDescription)
        }
    }
    
    private func fetchProgress() {
        do {
            let result = try getWordsProgressUseCase.execute().mapToDomain()
            state.progress = result
        } catch {
            print("fetch progress error: ", error)
            print("fetch progress localized: ", error.localizedDescription)
        }
    }
    
    private func fetchCurrentKanji() {
        state.viewState = .loading
        do {
            let result = try getAllKanjiUseCase.execute().mapToDomain()
            state.currentKanjis = result
                .compactMap { getTodayKanji($0) }
                .sorted(by: { ($0.addedIndex ?? 0) < ($1.addedIndex ?? 1) })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.state.viewState = .loaded
            }
        } catch {
            state.viewState = .error
        }
    }
    
    private func deleteKanji(_ kanji: Kanji) {
        defer {
            state.overlayLoading = false
        }
        do {
            try deleteKanjiUseCase.execute(param: kanji.asKanjiParam)
            // show toast success
            state.toast = Toast(message: "Successfully deleted kanji\nPlease refresh when you switch tabs", style: .success, isShowXMark: false)
        } catch {
            print("delete kotoba error: ", error)
            print("delete kotoba error localized: ", error.localizedDescription)
            // show toast error
            state.toast = Toast(message: "Failed to delete kanji", style: .error, isShowXMark: false)
        }
    }
    
    private func getTodayKanji(_ kanjis: Kanji) -> Kanji? {
        guard let date = kanjis.dateAdded else { return nil }
        return Calendar.current.isDate(date, inSameDayAs: Date()) ? kanjis : nil
    }
    
    @MainActor
    private func addKanji() async {
        guard let progress = state.progress, let (kanjiParam, progressParam) = validateParam(progress) else {
            state.buttonState = .error
            return
        }
        
        do {
            try addKanjiUseCase.execute(param: kanjiParam, progress: progressParam)
            state.buttonState = .success
            state.toast = Toast(
                message: "Successfully added kanji\nPlease refresh when you switch tabs",
                style: .success,
                isShowXMark: false
            )
        } catch {
            state.buttonState = .error
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
            jpExample: kanji.jpExample,
            enExample: kanji.enExample,
            dateAdded: Date(),
            addedIndex: progressIndex
        )
        let level: WordsProgressParam.Level = .init(rawValue: min(progress.getKanjiProgress, WordsProgressParam.Level(rawValue: kanji.jlptLevel.rawValue)?.rawValue ?? "N5")) ?? .n5
        let progressParam: WordsProgressParam = .init(
            id: progress.id,
            kanjiProgress: progressIndex + 1,
            kotobaProgress: progress.kotobaProgress,
            kanjiLevel: level,
            kotobaLevel: .init(rawValue: progress.kotobaLevel.rawValue) ?? .n5,
            lastKotobaUpdated: progress.lastKotobaUpdated,
            lastKanjiUpdated: Date()
        )
        
        return (kanjiParam, progressParam)
    }
    
    private func fetchNextKanji() -> (Kanji?, Int) {
        guard let progress = state.progress else {
            return (nil, state.progress?.kanjiProgress ?? 0)
        }
        let firstIndex = progress.kanjiProgress
        var kanji: Kanji?
        var latestIndex: Int = progress.kanjiProgress
        /// check if the next words/kotoba isn't already added in the current collection
        /// if it's already added then proceed next
        for index in firstIndex..<state.allKanjis.count {
            if !state.currentKanjis.contains(where: { kanji in
                return kanji.id == state.allKanjis[index].id
            }) {
                kanji = state.allKanjis[index]
                latestIndex = max(index, latestIndex)
                break
            }
        }
        return (kanji, latestIndex)
    }
}

extension HomeKanjiViewModel {
    struct State {
        var progress: WordsProgress?
        var allKanjis: [Kanji] = []
        var currentKanjis: [Kanji] = []
        var viewState: ViewState = .loading
        var toast: Toast?
        var overlayLoading: Bool = false
        var buttonState: ButtonState = .idle
        var config: AsyncButtonView.Config {
            .init(
                title: buttonState.rawValue,
                foregroundColor: .white,
                background: buttonState.color,
                symbolImage: buttonState.image
            )
        }
    }
    
    enum Action {
        case onAppear
        case didTapAddKanji
        case didTapDeleteKanji(Kanji)
    }
    
    enum ViewState {
        case loaded
        case loading
        case error
    }
    
    enum ButtonState: String {
        case idle = "Add New Word"
        case loading = "Adding Word..."
        case success = "Successfully Added"
        case error = "Failed to Add"
        
        var color: Color {
            switch self {
            case .idle:
                return DefaultColors.Button.primaryBg
            case .loading:
                return .blue
            case .success:
                return .green
            case .error:
                return .red
            }
        }
        
        var image: String? {
            switch self {
            case .idle:
                return "plus.arrow.trianglehead.clockwise"
            case .loading:
                return nil
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "xmark.circle.fill"
            }
        }
    }
}


