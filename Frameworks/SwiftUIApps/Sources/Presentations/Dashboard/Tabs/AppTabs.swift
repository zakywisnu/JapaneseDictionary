//
//  AppTabs.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 19/05/25.
//

import SwiftUI

public class AppTabsViewModel: ObservableObject {
    @Published public var appTab: AppTabs = .home
    
    public init(appTab: AppTabs) {
        self.appTab = appTab
    }
}

public enum AppTabs: Hashable, CaseIterable {
    case home
    case collection
    case profile
    
    public var title: String {
        switch self {
        case .home:
            "Today"
        case .collection:
            "Collection"
        case .profile:
            "Progress"
        }
    }
    
    /// Leaf for Today: the daily word is what grows the forest (see DESIGN.md).
    public var symbolImage: String {
        switch self {
        case .home:
            "leaf"
        case .collection:
            "books.vertical"
        case .profile:
            "chart.bar"
        }
    }
    
    @ViewBuilder
    func view() -> some View {
        switch self {
        case .home:
            AppComposer.shared.makeHomeView()
        case .collection:
            AppComposer.shared.makeCollectionView()
        case .profile:
            AppComposer.shared.makeProfileView()
        }
    }
}
