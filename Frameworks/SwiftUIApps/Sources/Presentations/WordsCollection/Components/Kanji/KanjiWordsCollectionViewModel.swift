//
//  KanjiWordsCollectionViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//

import Foundation
import Observation
import DomainKit

@Observable
public class KanjiWordsCollectionViewModel {
    var state: State
    
    private let getAllKanjiUseCase: GetAllKanjiUseCase
    private let deleteKanjiUseCase: DeleteKanjiUseCase
    
    public init(
        getAllKanjiUseCase: GetAllKanjiUseCase,
        deleteKanjiUseCase: DeleteKanjiUseCase
    ) {
        self.state = .init()
        self.getAllKanjiUseCase = getAllKanjiUseCase
        self.deleteKanjiUseCase = deleteKanjiUseCase
    }
    
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            fetchKanjis()
        case let .didTapDelete(id):
            guard let kanji = state.kanjis.first(where: { $0.id == id }) else { return }
            do {
                try deleteKanjiUseCase.execute(param: kanji.asKanjiParam)
            } catch {
                state.errorMessage = "\(kanji.kanji) couldn't be removed. Try again."
            }
            fetchKanjis()
        case .didDismissError:
            state.errorMessage = nil
        }
    }
    
    private func fetchKanjis() {
        do {
            state.kanjis = try getAllKanjiUseCase.execute()
                .mapToDomain()
                .sorted(by: { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) })
            state.loadState = .loaded
        } catch {
            state.loadState = .failed
        }
    }
}

public extension KanjiWordsCollectionViewModel {
    struct State {
        var kanjis: [Kanji] = []
        var loadState: TodayLoadState = .loading
        var errorMessage: String?
    }
    
    enum Action {
        case onAppear
        case didTapDelete(String)
        case didDismissError
    }
}
