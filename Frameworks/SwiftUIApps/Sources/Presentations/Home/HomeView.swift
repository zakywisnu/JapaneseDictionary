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
                .addSpotlight(0, shape: .circle, text: "Tap to refresh your data")
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
        .addSpotlightOverlay(show: $viewModel.state.showSpotlight, currentSpot: $viewModel.state.currentSpot)
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel())
}
