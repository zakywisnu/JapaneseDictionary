//
//  AddKotobaUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 13/05/25.
//

import DataKit
import Foundation

public struct KotobaParam {
    public var id: String
    public var kanji: String
    public var furigana: String
    public var english: [String]
    public var jlptLevel: Level
    public var dateAdded: Date
    public var addedIndex: Int
    
    public init(
        id: String,
        kanji: String,
        furigana: String,
        english: [String],
        jlptLevel: Level,
        dateAdded: Date,
        addedIndex: Int
    ) {
        self.id = id
        self.kanji = kanji
        self.furigana = furigana
        self.english = english
        self.jlptLevel = jlptLevel
        self.dateAdded = dateAdded
        self.addedIndex = addedIndex
    }
    
    public enum Level: String {
        case n1 = "N1"
        case n2 = "N2"
        case n3 = "N3"
        case n4 = "N4"
        case n5 = "N5"
    }
    
    func toKotoba() -> KotobaDataModel {
        .init(
            id: id,
            kanji: kanji,
            furigana: furigana,
            english: english.map { ArrayString(value: $0) },
            jlptLevel: KotobaDataModel.Level(rawValue: jlptLevel.rawValue) ?? .n5,
            dateAdded: dateAdded,
            addedIndex: addedIndex
        )
    }
}

public protocol AddKotobaUseCase {
    func execute(param: KotobaParam, progress: WordsProgressParam) throws
}

public struct DefaultAddKotobaUseCase: AddKotobaUseCase {
    private let kotobaRepository: KotobaRepository
    private let wordsProgressRepository: WordsProgressRepository
    
    public init(kotobaRepository: KotobaRepository, wordsProgressRepository: WordsProgressRepository) {
        self.kotobaRepository = kotobaRepository
        self.wordsProgressRepository = wordsProgressRepository
    }
    
    public func execute(param: KotobaParam, progress: WordsProgressParam) throws {
        try kotobaRepository.add(param.toKotoba())
        try wordsProgressRepository.updateProgress(progress.asDataModel)
        UpdateProgressUserDefaults.update(progress)
    }
}
