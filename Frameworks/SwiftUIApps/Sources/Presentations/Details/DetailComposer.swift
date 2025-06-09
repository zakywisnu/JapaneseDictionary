//
//  DetailComposer.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 03/06/25.
//

import SwiftUI

extension AppComposer {
    @ViewBuilder
    func makeDetailView(_ config: DetailViewModel.Config) -> some View {
        let viewModel = DetailViewModel(
            config,
            deleteKanjiUseCase: useCase.deleteKanjiUseCase,
            deleteKotobaUseCase: useCase.deleteKotobaUseCase
        )
        DetailView(viewModel: viewModel)
    }
}
