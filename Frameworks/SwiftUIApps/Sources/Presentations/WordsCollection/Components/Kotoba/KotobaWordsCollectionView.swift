//
//  KotobaWordsCollectionView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//

import SwiftUI

struct KotobaWordsCollectionView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var appTabs: AppTabsViewModel
    @State var viewModel: KotobaWordsCollectionViewModel
    let query: String
    @State private var isReviewSetupPresented = false
    
    var body: some View {
        CollectionListView(
            noun: "word",
            entries: viewModel.state.kotobas.map(\.studyEntry),
            loadState: viewModel.state.loadState,
            query: query,
            onDelete: { viewModel.send(.didTapDelete($0.id)) },
            onSelect: { entry in
                guard let kotoba = viewModel.state.kotobas.first(where: { $0.id == entry.id }) else { return }
                router.push(.detail(.init(kotoba: kotoba, kanji: nil)), hideNavBar: false)
            },
            onRetry: { viewModel.send(.onAppear) },
            onGoToToday: { appTabs.appTab = .home },
            onReview: { isReviewSetupPresented = true }
        )
        .sheet(isPresented: $isReviewSetupPresented) {
            ReviewSetupView(kind: .words, items: viewModel.state.kotobas.map(ReviewItem.init(word:))) { session in
                router.push(.review(session), hideNavBar: false)
            }
        }
        .onAppear { viewModel.send(.onAppear) }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { viewModel.state.errorMessage != nil }, set: { _ in viewModel.send(.didDismissError) })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.state.errorMessage ?? "")
        }
    }
}
