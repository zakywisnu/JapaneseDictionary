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
    private let mutationRepository: StudyMutationRepository

    public init(mutationRepository: StudyMutationRepository) {
        self.mutationRepository = mutationRepository
    }

    public func execute(param: KanjiParam) throws {
        let progress = try mutationRepository.delete(id: .init(kind: .kanji, id: param.id))
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

extension StudyProgress {
    func mapToParam() -> WordsProgressParam {
        .init(id: id, kanjiProgress: kanjiProgress, kotobaProgress: kotobaProgress,
              kanjiLevel: .init(rawValue: kanjiLevel) ?? .n5,
              kotobaLevel: .init(rawValue: kotobaLevel) ?? .n5,
              lastKotobaUpdated: lastKotobaUpdated, lastKanjiUpdated: lastKanjiUpdated,
              kanjiIndex: kanjiIndex, kotobaIndex: kotobaIndex)
    }
}
