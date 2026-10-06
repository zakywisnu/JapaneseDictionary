//
//  ProfileViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 02/06/25.
//

import DomainKit
import Observation
import SwiftUI

@Observable
public final class ProfileViewModel {
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
        case .onAppear:
            if state.totalKotoba == 0 || state.totalKanji == 0 {
                fetchTotals()
            }
            fetchProgress()
        }
    }
    
    private func fetchProgress() {
        do {
            state.progress = try getWordsProgressUseCase.execute().mapToDomain()
            state.loadState = state.totalKotoba > 0 && state.totalKanji > 0 ? .loaded : .failed
        } catch {
            state.loadState = .failed
        }
    }
    
    private func fetchTotals() {
        state.totalKotoba = (try? getKotobaDataUseCase.execute().count) ?? 0
        state.totalKanji = (try? getKanjiDataUseCase.execute().count) ?? 0
    }
}

extension ProfileViewModel {
    struct State {
        var loadState: TodayLoadState = .loading
        var progress: WordsProgress?
        var totalKotoba = 0
        var totalKanji = 0
    }
    
    enum Action {
        case onAppear
    }
}
