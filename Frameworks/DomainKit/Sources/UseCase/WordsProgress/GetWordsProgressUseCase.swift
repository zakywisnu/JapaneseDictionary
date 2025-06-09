//
//  GetWordsProgressUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import Foundation
import DataKit

public protocol GetWordsProgressUseCase {
    func execute() throws -> WordsProgressModel
}

public struct DefaultGetWordsProgressUseCase: GetWordsProgressUseCase {
    private let wordsProgressRepository: WordsProgressRepository
    
    public init(wordsProgressRepository: WordsProgressRepository) {
        self.wordsProgressRepository = wordsProgressRepository
    }
    
    public func execute() throws -> WordsProgressModel {
        try wordsProgressRepository.getProgress()
    }
}
