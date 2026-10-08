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
    case review(ReviewSession)
    case sources
    case backup
    case dictionary
    case dictionaryEntry(String)
    
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
        case let .review(session):
            AppComposer.shared.makeReviewView(session)
        case .sources:
            SourcesView()
        case .backup:
            AppComposer.shared.makeBackupView()
        case .dictionary:
            AppComposer.shared.makeDictionaryBrowseView()
        case let .dictionaryEntry(id):
            AppComposer.shared.makeDictionaryBrowseDetailView(catalogID: id)
        }
    }
}
