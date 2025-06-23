//
//  GetKanjiWaniKaniUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 23/06/25.
//

import Foundation
import DataKit

public struct DefaultGetKanjiWaniKaniUseCase: GetKanjiDataUseCase {
    let repository: VocabRepository
    
    public init(repository: VocabRepository) {
        self.repository = repository
    }
    
    public func execute() throws -> [DataKit.KanjiDataModel] {
        try repository.fetchKanjiWanikaniData()
    }
}
