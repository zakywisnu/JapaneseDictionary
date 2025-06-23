//
//  HomeView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 17/05/25.
//

import SwiftUI
import DomainKit
import ZeroDesignKit

struct HomeView: View {
    @EnvironmentObject var appTabs: AppTabsViewModel
    @Bindable private var viewModel: HomeViewModel
    
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        headerView
    }
    
    var headerView: some View {
        VStack {
            HeaderView(
                config: .init(
                    title: "Home",
                    showBackButton: false
                ),
                onBackTapped: nil
            ) {
                HStack(spacing: 16) {
                    Button {
                        viewModel.send(.onRetry)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                .addCoachmark(
                    0,
                    with: .init(
                        title: .init(
                            text: "Refresh Button",
                            font: .caption,
                            fontWeight: .bold,
                            foreground: .black
                        ),
                        description: .init(
                            text: "Tap to refresh your data",
                            font: .caption2,
                            fontWeight: .semibold,
                            foreground: .black
                        )
                        ,radius: 16
                    )
                )
            } content: {
                TabViewPager(
                    selectedTab: $viewModel.state.selectedTab
                )
                .id(viewModel.state.refreshID)
                .padding(.top, 16)
            }
            .background(DefaultColors.background.opacity(0.4))
        }
        .onFirstAppear {
            viewModel.send(.onAppear)
        }
        .addCoachmarkOverlay(show: $viewModel.state.showCoachmark, currentSpot: $viewModel.state.currentSpot) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                appTabs.appTab = .collection
            }
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel())
}
