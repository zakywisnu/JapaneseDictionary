//
//  GetKotobaDataUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 13/05/25.
//

import DataKit

public protocol GetKotobaDataUseCase {
    func execute() throws -> [KotobaDataModel]
}

public struct DefaultGetKotobaUseCase: GetKotobaDataUseCase {
    let repository: VocabRepository
    
    public init(repository: VocabRepository) {
        self.repository = repository
    }
    
    public func execute() throws -> [KotobaDataModel] {
        return try repository.fetchKotobaData()
    }
}
