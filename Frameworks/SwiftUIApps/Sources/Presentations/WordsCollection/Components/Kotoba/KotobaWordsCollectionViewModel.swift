//
//  KotobaWordsCollectionViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 26/05/25.
//

import Foundation
import DomainKit
import ZeroDesignKit

@Observable
public class KotobaWordsCollectionViewModel {
    var state: State
    
    private let getAllKotobaUseCase: GetAllKotobaUseCase
    private let getWordsProgressUseCase: GetWordsProgressUseCase
    private let deleteKotobaUseCase: DeleteKotobaUseCase
    
    public init(
        getAllKotobaUseCase: GetAllKotobaUseCase,
        getWordsProgressUseCase: GetWordsProgressUseCase,
        deleteKotobaUseCase: DeleteKotobaUseCase
    ) {
        self.state = .init()
        self.getAllKotobaUseCase = getAllKotobaUseCase
        self.getWordsProgressUseCase = getWordsProgressUseCase
        self.deleteKotobaUseCase = deleteKotobaUseCase
    }
    
    func send(_ action: Action) async {
        switch action {
        case .onAppear:
            Task {
                fetchProgress()
                fetchCurrentKotoba()
            }
        case .didTapDelete:
            state.overlayLoading.toggle()
        }
    }
}

extension KotobaWordsCollectionViewModel {
    private func fetchProgress() {
        do {
            let result = try getWordsProgressUseCase.execute().mapToDomain()
            state.progress = result
        } catch {
            print("fetch progress error: ", error)
            print("fetch progress localized: ", error.localizedDescription)
        }
    }
    
    private func fetchCurrentKotoba() {
        state.viewState = .loading
        do {
            let result = try getAllKotobaUseCase.execute().mapToKotobas()
            state.currentKotobas = result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.state.viewState = .loaded
            }
        } catch {
            print("current kotoba error: ", error)
            print("current kotoba error localized: ", error.localizedDescription)
            state.viewState = .error
        }
    }
    
    private func deleteKotoba(_ kotoba: Kotoba) {
        defer {
            state.overlayLoading = false
        }
        do {
            try deleteKotobaUseCase.execute(kotoba: kotoba.asKotobaParam)
            // show toast success
            state.toast = Toast(message: "Successfully deleted kotoba\nPlease refresh when you switch tabs", style: .success, isShowXMark: false)
        } catch {
            print("delete kotoba error: ", error)
            print("delete kotoba error localized: ", error.localizedDescription)
            // show toast error
            state.toast = Toast(message: "Failed to delete kotoba", style: .error, isShowXMark: false)
        }
    }
}

public extension KotobaWordsCollectionViewModel {
    struct State {
        var progress: WordsProgress?
        var currentKotobas: [Kotoba] = []
        var viewState: ViewState = .loading
        var overlayLoading: Bool = false
        var toast: Toast?
    }
    
    enum Action {
        case onAppear
        case didTapDelete
    }
    
    enum ViewState {
        case loaded
        case loading
        case error
    }
}
