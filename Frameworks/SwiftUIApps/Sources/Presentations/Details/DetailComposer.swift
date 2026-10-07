//
//  DetailComposer.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 03/06/25.
//

import SwiftUI
import DataKit

extension AppComposer {
    func makeDetailView(_ config: DetailViewModel.Config) -> some View {
        DetailCompositionView(composer: self, config: config)
    }
}

private struct DetailCompositionView: View {
    let composer: AppComposer
    let config: DetailViewModel.Config

    var body: some View {
        let viewModel = DetailViewModel(
            config,
            deleteKanjiUseCase: composer.useCase.deleteKanjiUseCase,
            deleteKotobaUseCase: composer.useCase.deleteKotobaUseCase
        )
        let memoryAid = config.kanji == nil ? config.kotoba.map { kotoba in
            MemoryAidViewModel(
                word: MemoryAidWord(id: kotoba.id, headword: kotoba.kanji, reading: kotoba.furigana,
                                    meanings: kotoba.english, level: kotoba.jlptLevel.rawValue),
                repository: StandardMemoryAidRepository(store: composer.store),
                generator: MemoryAidGeneratorFactory.make()
            )
        } : nil
        DetailView(viewModel: viewModel, examples: composer.examples, memoryAid: memoryAid)
    }
}
