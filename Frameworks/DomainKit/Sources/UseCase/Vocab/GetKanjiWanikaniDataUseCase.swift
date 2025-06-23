//
//  GetKanjiWanikaniDataUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 13/05/25.
//

import DataKit
import Foundation

public protocol GetKanjiWanikaniDataUseCase {
    func execute() throws -> Data
}

public struct DefaultGetKanjiWanikaniDataUseCase: GetKanjiWanikaniDataUseCase {
    let repository: VocabRepository
    
    public init(repository: VocabRepository) {
        self.repository = repository
    }
    
    public func execute() throws -> Data {
        try repository.fetchKanjiWanikaniData()
    }
} 