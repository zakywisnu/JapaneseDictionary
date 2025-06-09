//
//  DeleteKotobaUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 14/05/25.
//

import DataKit

public protocol DeleteKotobaUseCase {
    func execute(kotoba: KotobaParam) throws
}

public struct DefaultDeleteKotobaUseCase: DeleteKotobaUseCase {
    private let kotobaRepository: KotobaRepository
    private let wordsProgressRepository: WordsProgressRepository
    
    public init(kotobaRepository: KotobaRepository, wordsProgressRepository: WordsProgressRepository) {
        self.kotobaRepository = kotobaRepository
        self.wordsProgressRepository = wordsProgressRepository
    }
    
    public func execute(kotoba: KotobaParam) throws {
        try kotobaRepository.delete(id: kotoba.id)
        let progress = try wordsProgressRepository.getProgress()
        progress.kotobaProgress = kotoba.addedIndex
        progress.kotobaLevel = .init(
            rawValue: max(
                WordsProgressModel.Level(rawValue: progress.kotobaLevel.rawValue)?.rawValue ?? "N5",
                WordsProgressModel.Level(rawValue: kotoba.jlptLevel.rawValue)?.rawValue ?? "N5"
            )
        ) ?? .n5
        try wordsProgressRepository.updateProgress(progress)
        UpdateProgressUserDefaults.update(progress.mapToParam())
    }
}
