//
//  UpdateKanjiUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 14/05/25.
//

import Foundation
import DataKit

public protocol UpdateKanjiUseCase {
    func execute(_ param: KanjiParam) throws
}

public struct DefaultUpdateKanjiUseCase: UpdateKanjiUseCase {
    private let repository: KanjiRepository
    
    public init(repository: KanjiRepository) {
        self.repository = repository
    }
    
    public func execute(_ param: KanjiParam) throws {
        try repository.update(param.toSwiftDataModel())
    }
}
