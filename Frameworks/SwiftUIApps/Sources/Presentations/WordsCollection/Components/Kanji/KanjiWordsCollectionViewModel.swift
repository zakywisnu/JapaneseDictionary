//
//  KanjiWordsCollectionViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//
import Foundation
import DomainKit
import ZeroDesignKit

@Observable
public class KanjiWordsCollectionViewModel {
    var state: State
    
    private let getAllKanjiUseCase: GetAllKanjiUseCase
    private let getWordsProgressUseCase: GetWordsProgressUseCase
    private let deleteKanjiUseCase: DeleteKanjiUseCase
    
    public init(
        getAllKanjiUseCase: GetAllKanjiUseCase,
        getWordsProgressUseCase: GetWordsProgressUseCase,
        deleteKanjiUseCase: DeleteKanjiUseCase
    ) {
        self.state = .init()
        self.getAllKanjiUseCase = getAllKanjiUseCase
        self.getWordsProgressUseCase = getWordsProgressUseCase
        self.deleteKanjiUseCase = deleteKanjiUseCase
    }
    
    func send(_ action: Action) async {
        switch action {
        case .onAppear:
            Task {
                fetchAll()
            }
        case let .didTapDelete(kanji):
            state.overlayLoading.toggle()
            deleteKanji(kanji)
            fetchAll()
        }
    }
}

extension KanjiWordsCollectionViewModel {
    private func fetchAll() {
        fetchProgress()
        fetchCurrentKanji()
    }
    
    private func fetchProgress() {
        do {
            let result = try getWordsProgressUseCase.execute().mapToDomain()
            state.progress = result
        } catch {
            print("fetch progress error: ", error)
            print("fetch progress localized: ", error.localizedDescription)
        }
    }
    
    private func fetchCurrentKanji() {
        state.viewState = .loading
        do {
            let result = try getAllKanjiUseCase.execute().mapToDomain()
            state.currentKanjis = result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.state.viewState = .loaded
            }
        } catch {
            print("current kotoba error: ", error)
            print("current kotoba error localized: ", error.localizedDescription)
            state.viewState = .error
        }
    }
    
    private func deleteKanji(_ kanji: Kanji) {
        defer {
            state.overlayLoading = false
        }
        do {
            try deleteKanjiUseCase.execute(param: kanji.asKanjiParam)
            // show toast success
            state.toast = Toast(message: "Successfully deleted kanji\nPlease refresh when you switch tabs", style: .success, isShowXMark: false)
        } catch {
            print("delete kotoba error: ", error)
            print("delete kotoba error localized: ", error.localizedDescription)
            // show toast error
            state.toast = Toast(message: "Failed to delete kanji", style: .error, isShowXMark: false)
        }
    }
}

public extension KanjiWordsCollectionViewModel {
    struct State {
        var progress: WordsProgress?
        var currentKanjis: [Kanji] = []
        var viewState: ViewState = .loading
        var overlayLoading: Bool = false
        var toast: Toast?
    }
    
    enum Action {
        case onAppear
        case didTapDelete(Kanji)
    }
    
    enum ViewState {
        case loaded
        case loading
        case error
    }
}
