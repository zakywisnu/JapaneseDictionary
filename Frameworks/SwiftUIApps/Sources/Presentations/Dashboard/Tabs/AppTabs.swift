//
//  AppTabs.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 19/05/25.
//

import ZeroDesignKit
import SwiftUI

enum AppTabs: TabItem, CaseIterable {
    case home
    case collection
    case profile
    
    var title: String {
        switch self {
        case .home:
            "Home"
        case .collection:
            "Collection"
        case .profile:
            "Profile"
        }
    }
    
    var symbolImage: String {
        switch self {
        case .home:
            "house"
        case .collection:
            "square.on.square"
        case .profile:
            "person.circle"
        }
    }
    
    var activeBackgroundColor: Color {
        DefaultColors.primary
    }
    
    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
    
    func view() -> some View {
        switch self {
        case .home:
            AppComposer.shared.composeHome()
                .id(AppTabs.home)
        case .collection:
            AppComposer.shared.composeCollection()
                .id(AppTabs.collection)
        case .profile:
            AppComposer.shared.makeProfileView()
        }
    }
}

private extension AppComposer {
    @ViewBuilder
    func composeCollection() -> some View {
        let viewModel = WordsCollectionViewModel()
        WordsCollectionView(viewModel: viewModel)
    }
    
    @ViewBuilder
    func composeHome() -> some View {
        let viewModel = HomeViewModel()
        HomeView(viewModel: viewModel)
    }
}
