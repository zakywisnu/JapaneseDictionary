//
//  KotobaWordsCollectionView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//

import SwiftUI
import ZeroDesignKit

struct KotobaWordsCollectionView: View {
    @EnvironmentObject var router: AppRouter
    @State private var viewModel: KotobaWordsCollectionViewModel
    
    public init(viewModel: KotobaWordsCollectionViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            switch viewModel.state.viewState {
            case .loaded:
                if viewModel.state.currentKotobas.isEmpty {
                    emptyView()
                        .addCoachmark(
                            0,
                            with: .init(
                                shape: .rounded,
                                title: .init(
                                    text: "Collections of words",
                                    font: .caption,
                                    fontWeight: .bold,
                                    foreground: .black
                                ),
                                description: .init(
                                    text: "All of your words collection progress will be here",
                                    font: .caption2,
                                    fontWeight: .semibold,
                                    foreground: .black
                                ),
                                radius: 4
                            )
                        )
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
            Task {
                await viewModel.send(.onAppear)
            }
        }
        .loading(viewModel.state.overlayLoading)
        .toast(toast: $viewModel.state.toast)
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
                            shape: .circle) { resetPosition in
                                resetPosition.toggle()
                                Task {
                                    await viewModel.send(.didTapDelete)
                                }
                            }
                    }
                    .padding(.vertical, 4)
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
            Text("You haven't learned any kana yet!\nStart by adding some new ones.")
                .font(.title3)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
