//
//  UpdateWordsProgressUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import Foundation
import DataKit

public struct WordsProgressParam: Codable {
    public var id: String
    public var kanjiProgress: Int
    public var kotobaProgress: Int
    public var kanjiLevel: Level
    public var kotobaLevel: Level
    public var lastKotobaUpdated: Date
    public var lastKanjiUpdated: Date
    
    public init(
        id: String,
        kanjiProgress: Int,
        kotobaProgress: Int,
        kanjiLevel: Level,
        kotobaLevel: Level,
        lastKotobaUpdated: Date,
        lastKanjiUpdated: Date
    ) {
        self.id = id
        self.kanjiProgress = kanjiProgress
        self.kotobaProgress = kotobaProgress
        self.kanjiLevel = kanjiLevel
        self.kotobaLevel = kotobaLevel
        self.lastKotobaUpdated = lastKotobaUpdated
        self.lastKanjiUpdated = lastKanjiUpdated
    }
    
    public enum Level: String, Codable {
        case n1 = "N1"
        case n2 = "N2"
        case n3 = "N3"
        case n4 = "N4"
        case n5 = "N5"
        
        public init?(rawValue: String) {
            switch rawValue {
            case "N1":
                self = .n1
            case "N2":
                self = .n2
            case "N3":
                self = .n3
            case "N4":
                self = .n4
            case "N5":
                self = .n5
            default:
                self = .n5
            }
        }
    }
    
    var asDataModel: WordsProgressModel {
        WordsProgressModel(
            id: id,
            kanjiProgress: kanjiProgress,
            kotobaProgress: kotobaProgress,
            kanjiLevel: .init(rawValue: kanjiLevel.rawValue) ?? .n5,
            kotobaLevel: .init(rawValue: kotobaLevel.rawValue) ?? .n5,
            lastKotobaUpdated: lastKotobaUpdated,
            lastKanjiUpdated: lastKanjiUpdated
        )
    }
}

extension Array where Element == WordsProgressParam {
    public var asDataModel: [WordsProgressModel] {
        map(\.asDataModel)
    }
}

public protocol UpdateWordsProgressUseCase {
    func execute(words: WordsProgressParam) throws
}

public struct DefaultUpdateWordsProgressUseCase: UpdateWordsProgressUseCase {
    private let wordsProgressRepository: WordsProgressRepository
    
    public init(wordsProgressRepository: WordsProgressRepository) {
        self.wordsProgressRepository = wordsProgressRepository
    }
    
    public func execute(words: WordsProgressParam) throws {
        try wordsProgressRepository.updateProgress(words.asDataModel)
        UpdateProgressUserDefaults.update(words)
    }
}
