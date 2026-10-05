//
//  DetailViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 03/06/25.
//

import Foundation
import Observation
import DomainKit

@Observable
public final class DetailViewModel {
    var state: State
    
    private let deleteKanjiUseCase: DeleteKanjiUseCase
    private let deleteKotobaUseCase: DeleteKotobaUseCase
    
    public init(
        _ config: Config,
        deleteKanjiUseCase: DeleteKanjiUseCase,
        deleteKotobaUseCase: DeleteKotobaUseCase
    ) {
        self.state = .init(kotoba: config.kotoba, kanji: config.kanji, type: config.type)
        self.deleteKanjiUseCase = deleteKanjiUseCase
        self.deleteKotobaUseCase = deleteKotobaUseCase
    }
    
    func send(_ action: Action) {
        switch action {
        case let .didConfirmDelete(onDeleted):
            do {
                switch state.type {
                case .kotoba:
                    guard let kotoba = state.kotoba else { return }
                    try deleteKotobaUseCase.execute(kotoba: kotoba.asKotobaParam)
                case .kanji:
                    guard let kanji = state.kanji else { return }
                    try deleteKanjiUseCase.execute(param: kanji.asKanjiParam)
                }
                onDeleted()
            } catch {
                state.errorMessage = "This \(state.type.noun) couldn't be removed. Try again."
            }
        case .didDismissError:
            state.errorMessage = nil
        }
    }
}

extension DetailViewModel {
    struct State {
        var kotoba: Kotoba?
        var kanji: Kanji?
        var type: DataType
        var errorMessage: String?
    }
    
    enum Action {
        case didConfirmDelete(() -> Void)
        case didDismissError
    }
    
    enum DataType {
        case kotoba
        case kanji
        
        var noun: String {
            switch self {
            case .kanji:
                return "kanji"
            case .kotoba:
                return "word"
            }
        }
        
        var title: String {
            switch self {
            case .kanji:
                return "Kanji"
            case .kotoba:
                return "Word"
            }
        }
    }
    
    public struct Config: Hashable {
        public static func == (lhs: DetailViewModel.Config, rhs: DetailViewModel.Config) -> Bool {
            lhs.kotoba == rhs.kotoba && lhs.kanji == rhs.kanji
        }
        
        let kotoba: Kotoba?
        let kanji: Kanji?
        var type: DataType {
            kanji != nil && kotoba == nil ? .kanji : .kotoba
        }
    }
}
