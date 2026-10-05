//
//  RouterView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 19/05/25.
//

import SwiftUI

public struct RouterView: View {
    @EnvironmentObject var router: AppRouter
    
    public init() {}
    
    public var body: some View {
        Group {
            switch router.currentRoot {
            case .dashboard: DashboardView()
            case .onboarding: AppComposer.shared.makeOnboardingView()
            default: AppSplashScreen()
            }
        }
        .transition(.opacity)
    }
}
