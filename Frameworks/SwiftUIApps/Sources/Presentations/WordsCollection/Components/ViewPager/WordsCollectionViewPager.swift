//
//  WordsCollectionViewPager.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//

import SwiftUI
import ZeroDesignKit

enum WordsCollectionViewPager: TabItem {
    case kotoba
    case kanji
    
    var title: String {
        switch self {
        case .kotoba:
            return "Kotoba Collection"
        case .kanji:
            return "Kanji Collection"
        }
    }
    
    var symbolImage: String {
        switch self {
        case .kotoba:
            return "character.textbox"
        case .kanji:
            return "character.magnify"
        }
    }
    
    var activeBackgroundColor: Color {
        DefaultColors.accent
    }
    
    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
    
    func view() -> some View {
        switch self {
        case .kotoba:
            AppComposer.shared.makeWordsCollectionKotobaView()
                .id(WordsCollectionViewPager.kotoba)
        case .kanji:
            AppComposer.shared.makeWordsCollectionKanjiView()
                .id(WordsCollectionViewPager.kanji)
        }
    }
}

private extension AppComposer {
    @ViewBuilder
    func makeWordsCollectionKotobaView() -> some View {
        let viewModel = KotobaWordsCollectionViewModel(
            getAllKotobaUseCase: useCase.getAllKotobaUseCase,
            getWordsProgressUseCase: useCase.getWordsProgressUseCase,
            deleteKotobaUseCase: useCase.deleteKotobaUseCase
        )
        KotobaWordsCollectionView(viewModel: viewModel)
    }
    
    @ViewBuilder
    func makeWordsCollectionKanjiView() -> some View {
        let viewModel = KanjiWordsCollectionViewModel(
            getAllKanjiUseCase: useCase.getAllKanjiUseCase,
            getWordsProgressUseCase: useCase.getWordsProgressUseCase,
            deleteKanjiUseCase: useCase.deleteKanjiUseCase
        )
        KanjiWordsCollectionView(viewModel: viewModel)
    }
}
