//
//  HomeKanjiView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import SwiftUI

struct HomeKanjiView: View {
    @EnvironmentObject var router: AppRouter
    @State var viewModel: HomeKanjiViewModel
    
    init(viewModel: HomeKanjiViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        TodayListView(
            dueCount: viewModel.state.dueItems.count,
            dueLoadState: viewModel.state.dueLoadState,
            onRetryDue: { viewModel.send(.retryDue) },
            onReviewDue: {
                let session = ReviewSession(kind: .kanji, items: viewModel.state.dueItems, origin: .due)
                router.push(.review(session), hideNavBar: false)
            },
            noun: "kanji",
            entries: viewModel.state.entries,
            loadState: viewModel.state.loadState,
            nextLevel: viewModel.state.nextLevel,
            hasFinished: viewModel.state.hasFinished,
            onAdd: { viewModel.send(.didTapAdd) },
            onDelete: { viewModel.send(.didTapDelete($0.id)) },
            onSelect: { entry in
                guard let kanji = viewModel.state.currentKanjis.first(where: { $0.id == entry.id }) else { return }
                router.push(.detail(.init(kotoba: nil, kanji: kanji)), hideNavBar: false)
            },
            onRetry: { viewModel.send(.onAppear) },
            onReview: {
                let session = ReviewSession(kind: .kanji, items: viewModel.state.currentKanjis.map(ReviewItem.init(kanji:)))
                router.push(.review(session), hideNavBar: false)
            }
        )
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
