//
//  ProfileView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 02/06/25.
//

import SwiftUI
import DomainKit
import ZeroDesignKit

public struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    
    public init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HeaderView(
            config: .init(title: "Profile", showBackButton: false)) {
                HStack(spacing: 16) {
                    Button {
                        viewModel.send(.didReload)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            } content: {
                ZStack {
                    switch viewModel.state.viewState {
                    case .loaded:
                        loadedContent()
//                            .addSpotlight(0, shape: .rounded, roundedRadius: 4, text: "Your Overall Vocabulary and Kanji Progress")
                            .addCoachmark(
                                0,
                                with: .init(
                                    shape: .rounded,
                                    title: .init(
                                        text: "Summary of your progress",
                                        font: .caption,
                                        fontWeight: .bold,
                                        foreground: .black
                                    ),
                                    description: .init(
                                        text: "Check out your overall progress here and see how much you've learned!",
                                        font: .caption2,
                                        fontWeight: .semibold,
                                        foreground: .black
                                    ),
                                    tooltipPosition: .bottom,
                                    tooltipAlignment: .auto,
                                    radius: 8,
                                    offset: .init(width: 0, height: 0)
                                )
                            )
                    case .loading:
                        BlockLoadingView(config: .init(blockSize: .init(width: 32, height: 32)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .error:
                        ErrorStateView(
                            image: Image(systemName: "exclamationmark.triangle"),
                            title: "Oops Something went wrong",
                            message: "Please wait a moment and try again.",
                            retryAction: {
                                viewModel.send(.didLoad)
                            }
                        )
                        .background(DefaultColors.background.opacity(0.4))
                    }
                }
            }
            .onFirstAppear {
                viewModel.send(.didLoad)
            }
            .background(DefaultColors.background.opacity(0.4))
            .addCoachmarkOverlay(show: $viewModel.state.showSpotlight, currentSpot: $viewModel.state.currentSpot)
    }
    
    @ViewBuilder
    private func loadedContent() -> some View {
        VStack(alignment: .center) {
            Image(systemName: "book.pages.fill")
                .resizable()
                .renderingMode(.original)
                .symbolEffect(.wiggle, options: .repeating)
                .foregroundStyle(DefaultColors.primary)
                .frame(width: 96, height: 96)
            
            VStack(spacing: 8) {
                Text("Your Learning Journey")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Track your progress and achievements as you master Japanese vocabulary and kanji")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 16)
            
            ContentGridView(activities: viewModel.state.activities)
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AppComposer.shared.makeProfileView()
}
