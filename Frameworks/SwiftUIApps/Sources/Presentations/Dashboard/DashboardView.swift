//
//  DashboardView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 19/05/25.
//

import SwiftUI
import DomainKit

struct DashboardView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var activeTab: AppTabsViewModel
    
    var body: some View {
        TabView(selection: $activeTab.appTab) {
            ForEach(AppTabs.allCases, id: \.self) { tab in
                tab.view()
                    .tabItem { Label(tab.title, systemImage: tab.symbolImage) }
                    .tag(tab)
            }
        }
        .tint(Forest.moss)
        .onReceive(NotificationCenter.default.publisher(for: .backupRestoreCompleted)) { _ in
            activeTab.appTab = .profile
            router.setRoot(.dashboard)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppTabsViewModel(appTab: .home))
}
