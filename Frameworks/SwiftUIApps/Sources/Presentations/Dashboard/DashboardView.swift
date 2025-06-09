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
    @State private var activeTab: AppTabs = .home
    var body: some View {
        AppTabBar(activeTab: $activeTab)
    }
}

#Preview {
    DashboardView()
}
