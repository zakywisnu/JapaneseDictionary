//
//  WordsCollectionViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//

import Observation
import SwiftUI

@Observable
final class WordsCollectionViewModel {
    @ObservationIgnored
    @AppStorage("hasShownWordsCollectionIntro") var hasShowIntro: Bool = false
    
    var state = State()
    
    init(state: WordsCollectionViewModel.State = State()) {
        self.state = state
    }
    
    func send(_ action: Action) {
        switch action {
        case .onRetry:
            state.refreshID = UUID()
        case .onAppear:
            Task {
                try await Task.sleep(for: .seconds(2))
                if !hasShowIntro {
                    state.showCoachmark = true
                }
                hasShowIntro = true
            }
        }
    }
}

extension WordsCollectionViewModel {
    struct State {
        var selectedTab: WordsCollectionViewPager? = .kotoba
        var showCoachmark: Bool = false
        var currentSpot: Int = 0
        var refreshID = UUID()
    }
    
    enum Action {
        case onRetry
        case onAppear
    }
}

