//
//  DeleteKanjiUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 14/05/25.
//

import Foundation
import DataKit

public protocol DeleteKanjiUseCase {
    func execute(param: KanjiParam) throws
}

public struct DefaultDeleteKanjiUseCase: DeleteKanjiUseCase {
    private let kanjiRepository: KanjiRepository
    private let wordsProgressRepository: WordsProgressRepository
    
    public init(
        kanjiRepository: KanjiRepository,
        wordsProgressRepository: WordsProgressRepository
    ) {
        self.kanjiRepository = kanjiRepository
        self.wordsProgressRepository = wordsProgressRepository
    }
    
    public func execute(param: KanjiParam) throws {
        try kanjiRepository.delete(id: param.id)
        let progress = try wordsProgressRepository.getProgress()
        progress.kanjiIndex = param.addedIndex
        progress.kanjiProgress = progress.kanjiProgress - 1
        progress.kanjiLevel = .init(
            rawValue: max(
                WordsProgressModel.Level(rawValue: progress.kotobaLevel.rawValue)?.rawValue ?? "N5",
                WordsProgressModel.Level(rawValue: param.jlptLevel.rawValue)?.rawValue ?? "N5"
            )
        ) ?? .n5
        try wordsProgressRepository.updateProgress(progress)
        UpdateProgressUserDefaults.update(progress.mapToParam())
    }
}

extension WordsProgressModel {
    func mapToParam() -> WordsProgressParam {
        .init(
            id: id,
            kanjiProgress: kanjiProgress,
            kotobaProgress: kotobaProgress,
            kanjiLevel: .init(rawValue: kanjiLevel.rawValue) ?? .n5,
            kotobaLevel: .init(rawValue: kotobaLevel.rawValue) ?? .n5,
            lastKotobaUpdated: lastKotobaUpdated,
            lastKanjiUpdated: lastKanjiUpdated,
            kanjiIndex: kanjiIndex,
            kotobaIndex: kotobaIndex
        )
    }
}
