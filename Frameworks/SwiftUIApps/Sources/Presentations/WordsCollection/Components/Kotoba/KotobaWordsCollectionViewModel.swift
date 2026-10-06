//
//  KotobaWordsCollectionViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//

import Foundation
import Observation
import DomainKit

@Observable
public class KotobaWordsCollectionViewModel {
    var state: State
    
    private let getAllKotobaUseCase: GetAllKotobaUseCase
    private let deleteKotobaUseCase: DeleteKotobaUseCase
    
    public init(
        getAllKotobaUseCase: GetAllKotobaUseCase,
        deleteKotobaUseCase: DeleteKotobaUseCase
    ) {
        self.state = .init()
        self.getAllKotobaUseCase = getAllKotobaUseCase
        self.deleteKotobaUseCase = deleteKotobaUseCase
    }
    
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            fetchKotobas()
        case let .didTapDelete(id):
            guard let kotoba = state.kotobas.first(where: { $0.id == id }) else { return }
            do {
                try deleteKotobaUseCase.execute(kotoba: kotoba.asKotobaParam)
            } catch {
                state.errorMessage = "\(kotoba.kanji) couldn't be removed. Try again."
            }
            fetchKotobas()
        case .didDismissError:
            state.errorMessage = nil
        }
    }
    
    private func fetchKotobas() {
        do {
            state.kotobas = try getAllKotobaUseCase.execute()
                .mapToKotobas()
                .sorted(by: { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) })
            state.loadState = .loaded
        } catch {
            state.loadState = .failed
        }
    }
}

public extension KotobaWordsCollectionViewModel {
    struct State {
        var kotobas: [Kotoba] = []
        var loadState: TodayLoadState = .loading
        var errorMessage: String?
    }
    
    enum Action {
        case onAppear
        case didTapDelete(String)
        case didDismissError
    }
}
