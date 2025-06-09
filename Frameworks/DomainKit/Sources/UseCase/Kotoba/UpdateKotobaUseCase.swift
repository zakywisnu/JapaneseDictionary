//
//  UpdateKotobaUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 14/05/25.
//

import DataKit

public protocol UpdateKotobaUseCase {
    func execute(_ param: KotobaParam) throws
}

public struct DefaultUpdateKotobaUseCase: UpdateKotobaUseCase {
    private let repository: KotobaRepository
    
    public init(repository: KotobaRepository) {
        self.repository = repository
    }
    
    public func execute(_ param: KotobaParam) throws {
        try repository.update(param.toKotoba())
    }
}
