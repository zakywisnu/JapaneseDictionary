//
//  WordsCollectionView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 24/05/25.
//

import SwiftUI
import ZeroDesignKit

struct WordsCollectionView: View {
    @Bindable private var viewModel: WordsCollectionViewModel
    
    init(viewModel: WordsCollectionViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        headerView
    }
    
    var headerView: some View {
        VStack {
            HeaderView(
                config: .init(
                    title: "Collection",
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
            } content: {
                TabViewPager(selectedTab: $viewModel.state.selectedTab)
                    .id(viewModel.state.refreshID)
                    .padding(.top, 16)
            }
            .background(DefaultColors.background.opacity(0.4))
        }
    }
}
#Preview {
    WordsCollectionView(viewModel: WordsCollectionViewModel())
}
