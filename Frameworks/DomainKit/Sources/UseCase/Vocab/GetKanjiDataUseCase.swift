//
//  GetKanjiDataUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 13/05/25.
//

import DataKit

public protocol GetKanjiDataUseCase {
    func execute() throws -> [KanjiDataModel]
}

public struct DefaultGetKanjiDataUseCase: GetKanjiDataUseCase {
    let repository: VocabRepository
    
    public init(repository: VocabRepository) {
        self.repository = repository
    }
    
    public func execute() throws -> [DataKit.KanjiDataModel] {
        try repository.fetchKanjiData()
    }
}
