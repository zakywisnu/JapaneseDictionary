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
    var state = State()
    
    init(state: WordsCollectionViewModel.State = State()) {
        self.state = state
    }
    
    func send(_ action: Action) {
        switch action {
        case .onRetry:
            state.refreshID = UUID()
        }
    }
}

extension WordsCollectionViewModel {
    struct State {
        var selectedTab: WordsCollectionViewPager? = .kotoba
        var refreshID = UUID()
    }
    
    enum Action {
        case onRetry
    }
}

