//
//  KanaViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import Observation
import SwiftUI
import DomainKit
import ZeroDesignKit

@Observable
final class HomeKotobaViewModel {
    var state: State
    
    private let getKotobaDataUseCase: GetKotobaDataUseCase
    private let getAllKotobaUseCase: GetAllKotobaUseCase
    private let getWordsProgressUseCase: GetWordsProgressUseCase
    private let addKotobaUseCase: AddKotobaUseCase
    private let deleteKotobaUseCase: DeleteKotobaUseCase
    
    init(
        state: State = .init(),
        getKotobaDataUseCase: GetKotobaDataUseCase,
        getAllKotobaUseCase: GetAllKotobaUseCase,
        getWordsProgressUseCase: GetWordsProgressUseCase,
        addKotobaUseCase: AddKotobaUseCase,
        deleteKotobaUseCase: DeleteKotobaUseCase
    ) {
        self.state = state
        self.getKotobaDataUseCase = getKotobaDataUseCase
        self.getAllKotobaUseCase = getAllKotobaUseCase
        self.getWordsProgressUseCase = getWordsProgressUseCase
        self.addKotobaUseCase = addKotobaUseCase
        self.deleteKotobaUseCase = deleteKotobaUseCase
    }
    
    @MainActor
    func send(_ action: Action) async throws {
        switch action {
        case .onAppear:
            fetchProgress()
            fetchAllKotoba()
            fetchCurrentKotoba()
        case .didTapAddKotoba:
            state.buttonState = .loading
            try await Task.sleep(for: .seconds(1))
            await addKotoba()
            try await Task.sleep(for: .seconds(2))
            state.buttonState = .idle
            fetchProgress()
            fetchCurrentKotoba()
        case let .didTapDeleteKotoba(kotoba):
            state.overlayLoading = true
            try await Task.sleep(for: .seconds(1))
            deleteKotoba(kotoba)
            fetchProgress()
            fetchCurrentKotoba()
        }
    }
}

extension HomeKotobaViewModel {
    private func fetchAllKotoba() {
        do {
            let result = try getKotobaDataUseCase.execute().mapToKotobas().sorted(by: { $0.jlptLevel.rawValue > $1.jlptLevel.rawValue })
            state.allKotobas = result
        } catch {
            print("all kotoba error: ", error)
            print("all kotoba error localized: ", error.localizedDescription)
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
    
    private func fetchCurrentKotoba() {
        state.viewState = .loading
        do {
            let result = try getAllKotobaUseCase.execute().mapToKotobas()

            state.currentKotobas = result
                .compactMap { getTodayKotoba($0) }
                .sorted(by: { ($0.addedIndex ?? 0) < ($1.addedIndex ?? 1) })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.state.viewState = .loaded
            }
        } catch {
            print("current kotoba error: ", error)
            print("current kotoba error localized: ", error.localizedDescription)
            state.viewState = .error
        }
    }
    
    private func deleteKotoba(_ kotoba: Kotoba) {
        defer {
            state.overlayLoading = false
        }
        do {
            try deleteKotobaUseCase.execute(kotoba: kotoba.asKotobaParam)
            // show toast success
            state.toast = Toast(message: "Successfully deleted kotoba\nPlease refresh when you switch tabs", style: .success, isShowXMark: false)
        } catch {
            print("delete kotoba error: ", error)
            print("delete kotoba error localized: ", error.localizedDescription)
            // show toast error
            state.toast = Toast(message: "Failed to delete kotoba", style: .error, isShowXMark: false)
        }
    }
    
    private func getTodayKotoba(_ kotobas: Kotoba) -> Kotoba? {
        guard let date = kotobas.dateAdded else { return nil }
        return Calendar.current.isDate(date, inSameDayAs: Date()) ? kotobas : nil
    }
    
    @MainActor
    private func addKotoba() async {
        guard let progress = state.progress else {
            state.buttonState = .error
            return
        }
        
        guard let (kotobaParam, progressParam) = validateParam(progress) else {
            return
        }
        
        do {
            try addKotobaUseCase.execute(param: kotobaParam, progress: progressParam)
            state.buttonState = .success
            state.toast = Toast(
                message: "Successfully added kotoba\nPlease refresh when you switch tabs",
                style: .success,
                isShowXMark: false
            )
        } catch {
            state.buttonState = .error
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
    
    private func fetchNextKotoba() -> (Kotoba?, Int) {
        guard let progress = state.progress else {
            return (nil, state.progress?.kotobaIndex ?? 0)
        }
        let firstIndex = progress.kotobaIndex
        var kotoba: Kotoba?
        var latestIndex: Int = progress.kotobaIndex
        /// check if the next words/kotoba isn't already added in the current collection
        /// if it's already added then proceed next
        for index in firstIndex..<state.allKotobas.count {
            if !state.currentKotobas.contains(where: { kotoba in
                return kotoba.id == state.allKotobas[index].id
            }) {
                kotoba = state.allKotobas[index]
                latestIndex = max(index, latestIndex)
                break
            }
        }
        return (kotoba, latestIndex)
    }
}

extension HomeKotobaViewModel {
    struct State {
        var progress: WordsProgress?
        var allKotobas: [Kotoba] = []
        var currentKotobas: [Kotoba] = []
        var viewState: ViewState = .loading
        var buttonState: ButtonState = .idle
        var toast: Toast?
        var overlayLoading: Bool = false
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
        case didTapAddKotoba
        case didTapDeleteKotoba(Kotoba)
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
