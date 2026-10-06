//
//  WordsCollectionViewPager.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//

import SwiftUI

extension AppComposer {
    @ViewBuilder
    func makeCollectionView() -> some View {
        WordsCollectionView()
    }
    
    @ViewBuilder
    func makeCollectionKotobaView(query: String) -> some View {
        let viewModel = KotobaWordsCollectionViewModel(
            getAllKotobaUseCase: useCase.getAllKotobaUseCase,
            deleteKotobaUseCase: useCase.deleteKotobaUseCase
        )
        KotobaWordsCollectionView(viewModel: viewModel, query: query)
    }
    
    @ViewBuilder
    func makeCollectionKanjiView(query: String) -> some View {
        let viewModel = KanjiWordsCollectionViewModel(
            getAllKanjiUseCase: useCase.getAllKanjiUseCase,
            deleteKanjiUseCase: useCase.deleteKanjiUseCase
        )
        KanjiWordsCollectionView(viewModel: viewModel, query: query)
    }
}
