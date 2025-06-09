//
//  AppsOnboardingView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 16/05/25.
//

import SwiftUI
import ZeroDesignKit
import DomainKit

public struct AppsOnboardingView: View {
    @EnvironmentObject var router: AppRouter
    var viewModel: AppsOnboardingViewModel
    
    public init(viewModel: AppsOnboardingViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack {
            OnboardingView(
                pages: viewModel.pages,
                config: .init(backgroundColor: DefaultColors.background.opacity(0.4))) {
                    withAnimation {
                        router.setRoot(.dashboard)
                    }
                }
        }
    }
}

#Preview {
    AppsOnboardingComposer.make()
}
