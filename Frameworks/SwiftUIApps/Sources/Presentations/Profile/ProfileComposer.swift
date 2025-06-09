//
//  ProfileComposer.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 02/06/25.
//

import DomainKit
import SwiftUI

extension AppComposer {
    @ViewBuilder
    func makeProfileView() -> some View {
        let viewModel = ProfileViewModel(
            getWordsProgressUseCase: useCase.getWordsProgressUseCase,
            getKanjiDataUseCase: useCase.getKanjiDataUseCase,
            getKotobaDataUseCase: useCase.getKotobaDataUseCase
        )
        ProfileView(viewModel: viewModel)
    }
}
