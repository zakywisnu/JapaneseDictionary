//
//  HomeKotobaView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import SwiftUI

struct HomeKotobaView: View {
    @EnvironmentObject var router: AppRouter
    @State var viewModel: HomeKotobaViewModel
    
    init(viewModel: HomeKotobaViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        TodayListView(
            noun: "word",
            entries: viewModel.state.entries,
            loadState: viewModel.state.loadState,
            nextLevel: viewModel.state.nextLevel,
            hasFinished: viewModel.state.hasFinished,
            onAdd: { viewModel.send(.didTapAdd) },
            onDelete: { viewModel.send(.didTapDelete($0.id)) },
            onSelect: { entry in
                guard let kotoba = viewModel.state.currentKotobas.first(where: { $0.id == entry.id }) else { return }
                router.push(.detail(.init(kotoba: kotoba, kanji: nil)), hideNavBar: false)
            },
            onRetry: { viewModel.send(.onAppear) },
            onReview: {
                let session = ReviewSession(kind: .words, items: viewModel.state.currentKotobas.map(ReviewItem.init(word:)))
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
