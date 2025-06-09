//
//  AppRoutes.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 16/05/25.
//

import SwiftUI
import ZeroCoreKit

public enum AppRoutes: Routable {
    case onboarding
    case splashScreen
    case dashboard
    case detail(DetailViewModel.Config)
    
    @ViewBuilder
    public func view() -> some View {
        switch self {
        case .onboarding:
            AppComposer.shared.makeOnboardingView()
        case .splashScreen:
            AppSplashScreen()
        case .dashboard:
            DashboardView()
        case let .detail(config):
            AppComposer.shared.makeDetailView(config)
        }
    }
}
