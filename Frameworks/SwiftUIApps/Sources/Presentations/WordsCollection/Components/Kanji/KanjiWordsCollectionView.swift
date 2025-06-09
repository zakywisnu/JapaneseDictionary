//
//  KanjiWordsCollectionViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//

import SwiftUI
import ZeroDesignKit

struct KanjiWordsCollectionView: View {
    @EnvironmentObject var router: AppRouter
    @State var viewModel: KanjiWordsCollectionViewModel
    
    init(viewModel: KanjiWordsCollectionViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            switch viewModel.state.viewState {
            case .loaded:
                if viewModel.state.currentKanjis.isEmpty {
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
            Task {
                await viewModel.send(.onAppear)
            }
        }
        .toast(toast: $viewModel.state.toast)
        .loading(viewModel.state.overlayLoading)
    }
    
    @ViewBuilder
    func loadedContent() -> some View {
        ScrollView(.vertical) {
            ForEach(viewModel.state.currentKanjis.prefix(30), id: \.id) { kanji in
                kanjiCardView(kanji)
                    .swipeActions {
                        SwipeAction(
                            symbolImage: "trash.fill",
                            tint: .white,
                            background: .red,
                            size: CGSize(width: 32, height: 32),
                            shape: .circle) { resetPosition in
                                resetPosition.toggle()
                                Task {
                                    await viewModel.send(.didTapDelete(kanji))
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
    func kanjiCardView(_ kanji: Kanji) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "star.circle")
                .resizable()
                .frame(width: 24, height: 24)
            
            Text("\(kanji.kanji) | \(kanji.meanings.joined(separator: ", "))")
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
            Text("You haven't learned any kanji yet!\nStart by adding some new ones.")
                .font(.title3)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
