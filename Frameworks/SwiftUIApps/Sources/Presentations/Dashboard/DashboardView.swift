//
//  DashboardView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 19/05/25.
//

import SwiftUI
import ZeroDesignKit
import DomainKit

struct DashboardView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var activeTab: AppTabsViewModel
    
    var body: some View {
        AppTabBar(activeTab: $activeTab.appTab)
            .onChange(of: activeTab.appTab) { oldValue, newValue in
                activeTab.appTab = newValue
            }
    }
}

#Preview {
    DashboardView()
}
