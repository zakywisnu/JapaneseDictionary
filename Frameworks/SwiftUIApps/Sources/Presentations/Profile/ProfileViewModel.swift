//
//  ProfileViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 02/06/25.
//

import DomainKit
import Observation
import SwiftUI
import ZeroDesignKit

@Observable
public final class ProfileViewModel {
    @ObservationIgnored
    @AppStorage("hasShownProfileIntro") var hasShowIntro: Bool = false
    
    var state: State
    
    private var getWordsProgressUseCase: GetWordsProgressUseCase
    private var getKanjiDataUseCase: GetKanjiDataUseCase
    private var getKotobaDataUseCase: GetKotobaDataUseCase
    
    public init(
        getWordsProgressUseCase: GetWordsProgressUseCase,
        getKanjiDataUseCase: GetKanjiDataUseCase,
        getKotobaDataUseCase: GetKotobaDataUseCase
    ) {
        self.state = .init()
        self.getWordsProgressUseCase = getWordsProgressUseCase
        self.getKanjiDataUseCase = getKanjiDataUseCase
        self.getKotobaDataUseCase = getKotobaDataUseCase
    }
    
    func send(_ action: Action) {
        switch action {
        case .didLoad:
            getWordsProgress()
            getVocabData()
        case .didReload:
            getWordsProgress()
        }
    }
}

// MARK: Private methods
extension ProfileViewModel {
    private func getWordsProgress() {
        state.viewState = .loading
        Task { @MainActor in
            do {
                state.progress = try getWordsProgressUseCase.execute().mapToDomain()
                try await Task.sleep(for: .seconds(1))
                state.viewState = .loaded
                try await Task.sleep(for: .seconds(1))
                if !self.hasShowIntro {
                    withAnimation(.easeInOut) {
                        self.state.showSpotlight = true
                    }
                    self.hasShowIntro = true
                }
            } catch {
                state.viewState = .error
            }
        }
    }
    
    private func getVocabData() {
        do {
            state.kanjiData = try getKanjiDataUseCase.execute().mapToDomain()
            state.kotobaData = try getKotobaDataUseCase.execute().mapToKotobas()
        } catch {
            print("error when fetching vocab: ", error)
        }
    }
}

// MARK: Objects
extension ProfileViewModel {
    struct State {
        var viewState: ViewState = .loading
        var progress: WordsProgress?
        var kotobaData: [Kotoba] = []
        var kanjiData: [Kanji] = []
        var activities: [ContentGridData] {
            guard let progress, !kotobaData.isEmpty, !kanjiData.isEmpty else { return [] }
            return progress.mapToContent(totalKotoba: kotobaData.count, totalKanji: kanjiData.count)
        }
        var showSpotlight: Bool = false
        var currentSpot = 0
    }
    
    enum Action {
        case didLoad
        case didReload
    }
    
    enum ViewState {
        case loaded
        case loading
        case error
    }
}
