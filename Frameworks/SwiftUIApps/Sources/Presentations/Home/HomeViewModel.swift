//
//  HomeViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import Observation
import SwiftUI
import ZeroDesignKit

@Observable
final class HomeViewModel {
    @ObservationIgnored
    @AppStorage("hasShownKanaIntro") var hasShowIntro: Bool = false
    
    var state = State()
    
    init(state: HomeViewModel.State = State()) {
        self.state = state
    }
    
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self else { return }
                if !self.hasShowIntro {
                    withAnimation(.easeInOut) {
                        self.state.showCoachmark = true
                    }
                    self.hasShowIntro = true
                }
            }
        case .onRetry:
            state.refreshID = UUID()
        }
    }
}

extension HomeViewModel {
    struct State {
        var selectedTab: ViewPagerTabs? = .kotoba
        var refreshID = UUID()
        var showCoachmark: Bool = false
        var currentSpot = 0
    }
    
    enum Action {
        case onRetry
        case onAppear
    }
}
