//
//  HomeKotobaView+KanaView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import SwiftUI
import ZeroDesignKit
import DomainKit

struct HomeKotobaView: View {
    @EnvironmentObject var router: AppRouter
    @State var viewModel: HomeKotobaViewModel
    
    init(viewModel: HomeKotobaViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            switch viewModel.state.viewState {
            case .loaded:
                if viewModel.state.currentKotobas.isEmpty {
                    emptyView()
                } else {
                    loadedContent()
                }
            case .loading:
                BlockLoadingView(config: .init(blockSize: .init(width: 32, height: 32)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error:
                ErrorStateView(
                    image: Image(systemName: "exclamationmark.triangle"),
                    title: "Oops Something went wrong",
                    message: "Please wait a moment and try again.",
                    retryAction: { print("Retrying...") }
                )
                .background(DefaultColors.background.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onFirstAppear {
            Task { @MainActor in
                try await viewModel.send(.onAppear)
            }
        }
        .toast(toast: $viewModel.state.toast)
        .loading(viewModel.state.overlayLoading)
    }
    
    @ViewBuilder
    func loadedContent() -> some View {
        ScrollView(.vertical) {
            ForEach(viewModel.state.currentKotobas.prefix(30), id: \.id) { kotoba in
                kanaCardView(kotoba)
                    .onTapGesture {
                        router.push(.detail(.init(kotoba: kotoba, kanji: nil)), hideNavBar: true)
                    }
                    .swipeActions {
                        SwipeAction(
                            symbolImage: "trash.fill",
                            tint: .white,
                            background: .red,
                            size: CGSize(width: 32, height: 32),
                            shape: .circle) { resetPosition in
                                resetPosition.toggle()
                                Task {
                                    try await viewModel.send(.didTapDeleteKotoba(kotoba))
                                }
                            }
                    }
                    .padding(.vertical, 4)
            }
            AsyncButtonView(config: viewModel.state.config) {
                try? await viewModel.send(.didTapAddKotoba)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    func kanaCardView(_ kotoba: Kotoba) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "star.circle")
                .resizable()
                .frame(width: 24, height: 24)
            
            Text("\(kotoba.furigana) | \(kotoba.english.joined(separator: ", "))")
                .font(.subheadline)
            
            Spacer()
        }
        .padding(8)
        .background(Color.white)
        .clipShape(.capsule)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    func emptyView() -> some View {
        VStack(alignment: .center) {
            Spacer()
            Text("You haven't learned any kana yet!")
                .font(.title3)
            AsyncButtonView(config: viewModel.state.config) { @MainActor in
                try? await viewModel.send(.didTapAddKotoba)
            }
            .addSpotlight(1, shape: .circle, roundedRadius: 16, text: "Adding Words")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
