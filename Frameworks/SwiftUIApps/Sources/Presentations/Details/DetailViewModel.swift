//
//  DetailViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 03/06/25.
//

import Foundation
import Observation
import DomainKit
import DataKit

@Observable
public final class DetailViewModel {
    var state: State
    
    private let updateKotobaUseCase: (any UpdateKotobaUseCase)?
    private let loadCatalog: () throws -> VocabularyCatalogRepository
    private let deleteKanjiUseCase: DeleteKanjiUseCase
    private let deleteKotobaUseCase: DeleteKotobaUseCase
    
    public init(
        _ config: Config,
        deleteKanjiUseCase: DeleteKanjiUseCase,
        deleteKotobaUseCase: DeleteKotobaUseCase,
        updateKotobaUseCase: (any UpdateKotobaUseCase)? = nil,
        catalog: VocabularyCatalogRepository? = nil,
        loadCatalog: (() throws -> VocabularyCatalogRepository)? = nil
    ) {
        self.state = .init(kotoba: config.kotoba, kanji: config.kanji, type: config.type)
        self.deleteKanjiUseCase = deleteKanjiUseCase
        self.deleteKotobaUseCase = deleteKotobaUseCase
        self.updateKotobaUseCase = updateKotobaUseCase
        self.loadCatalog = loadCatalog ?? { try catalog ?? VocabularyCatalogRepository.bundled() }
    }
    
    var canUpdateStudyWord: Bool { updateKotobaUseCase != nil && state.studyUpdate != nil }

    func send(_ action: Action) {
        switch action {
        case .loadDictionary:
            guard let kotoba = state.kotoba else { return }
            do {
                let repository = try loadCatalog()
                state.dictionary = DictionaryLink.resolve(kotoba, in: repository)
            } catch {
                state.dictionary = .failed
            }
        case .confirmStudyUpdate:
            guard let original = state.kotoba,
                  case let .linked(word) = state.dictionary,
                  let updateKotobaUseCase,
                  let replacement = original.updatedStudyWord(from: word) else { return }
            do {
                try updateKotobaUseCase.execute(replacement.asKotobaParam)
                state.kotoba = replacement
                state.didUpdateStudyWord = true
            } catch {
                state.errorMessage = "The study word for \(original.kanji) couldn't be updated. Try again."
            }

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
        var dictionary: DictionaryLink = .loading
        var didUpdateStudyWord = false

        var studyUpdate: Kotoba? {
            guard let kotoba, case let .linked(word) = dictionary else { return nil }
            return kotoba.updatedStudyWord(from: word)
        }

    }
    
    enum Action {
        case loadDictionary
        case confirmStudyUpdate
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
