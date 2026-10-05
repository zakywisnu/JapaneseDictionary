//
//  KanjiWordsCollectionView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//

import SwiftUI

struct KanjiWordsCollectionView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var appTabs: AppTabsViewModel
    @State var viewModel: KanjiWordsCollectionViewModel
    let query: String
    
    var body: some View {
        CollectionListView(
            noun: "kanji",
            entries: viewModel.state.kanjis.map(\.studyEntry),
            loadState: viewModel.state.loadState,
            query: query,
            onDelete: { viewModel.send(.didTapDelete($0.id)) },
            onSelect: { entry in
                guard let kanji = viewModel.state.kanjis.first(where: { $0.id == entry.id }) else { return }
                router.push(.detail(.init(kotoba: nil, kanji: kanji)), hideNavBar: false)
            },
            onRetry: { viewModel.send(.onAppear) },
            onGoToToday: { appTabs.appTab = .home }
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
