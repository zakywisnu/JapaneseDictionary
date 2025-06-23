//
//  AppTabs.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 19/05/25.
//

import ZeroDesignKit
import SwiftUI

public class AppTabsViewModel: ObservableObject {
    @Published public var appTab: AppTabs = .home
    
    public init(appTab: AppTabs) {
        self.appTab = appTab
    }
}

public enum AppTabs: TabItem, CaseIterable {
    case home
    case collection
    case profile
    
    public var title: String {
        switch self {
        case .home:
            "Home"
        case .collection:
            "Collection"
        case .profile:
            "Profile"
        }
    }
    
    public var symbolImage: String {
        switch self {
        case .home:
            "house"
        case .collection:
            "square.on.square"
        case .profile:
            "person.circle"
        }
    }
    
    public var activeBackgroundColor: Color {
        DefaultColors.primary
    }
    
    public var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
    
    public func view() -> some View {
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
