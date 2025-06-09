//
//  DetailViewModel.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 03/06/25.
//

import Foundation
import Observation
import DomainKit
import ZeroDesignKit

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
        case let .didTapDelete(completion):
            Task { @MainActor in
                await delete(completion)
            }
        }
    }
}

// MARK: Private methods
extension DetailViewModel {
    @MainActor
    private func delete(_ completion: @escaping () -> Void) async {
        defer {
            state.isLoading = false
        }
        state.isLoading = true
        do {
            try await Task.sleep(for: .seconds(2))
            switch state.type {
            case .kotoba:
                guard let kotoba = state.kotoba else { return }
                try deleteKotobaUseCase.execute(kotoba: kotoba.asKotobaParam)
                state.toast = Toast(message: state.type.successMessage, style: .success)
            case .kanji:
                guard let kanji = state.kanji else { return }
                try deleteKanjiUseCase.execute(param: kanji.asKanjiParam)
                state.toast = Toast(message: state.type.successMessage, style: .success)
            }
            completion()
        } catch {
            state.toast = Toast(message: state.type.errorMessage, style: .error)
        }
    }
}

// MARK: Objects
extension DetailViewModel {
    struct State {
        var isLoading: Bool = false
        var kotoba: Kotoba?
        var kanji: Kanji?
        var type: DataType
        var toast: Toast?
        
        var drawerButtonConfig: CustomDrawerConfig = .default
    }
    
    enum Action {
        case didTapDelete(() -> Void)
    }
    
    enum DataType {
        case kotoba
        case kanji
        
        var errorMessage: String {
            switch self {
            case .kanji:
                return "Failed to delete Kanji"
            case .kotoba:
                return "Failed to delete Kotoba"
            }
        }
        
        var successMessage: String {
            switch self {
            case .kanji:
                return "Successfully deleted Kanji\nPlease refresh when you navigate to other tabs"
            case .kotoba:
                return "Successfully deleted Kotoba\nPlease refresh when you navigate to other tabs"
            }
        }
        
        var title: String {
            switch self {
            case .kanji:
                return "Kanji"
            case .kotoba:
                return "Kotoba"
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
            if let _ = kotoba {
                return .kotoba
            } else if let _ = kanji {
                return .kanji
            }
            return .kotoba
        }
    }
}
