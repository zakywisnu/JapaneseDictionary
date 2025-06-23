//
//  AddKanjiUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 14/05/25.
//

import Foundation
import DataKit

public struct KanjiParam {
    public var id: String
    public var kanji: String
    public var stroke: Int
    public var onyomi: [String]
    public var kunyomi: [String]
    public var jlptLevel: Level
    public var meanings: [String]
    public var dateAdded: Date
    public var addedIndex: Int
    
    public init(
        id: String,
        kanji: String,
        stroke: Int,
        onyomi: [String],
        kunyomi: [String],
        jlptLevel: Level,
        meanings: [String],
        dateAdded: Date,
        addedIndex: Int
    ) {
        self.id = id
        self.kanji = kanji
        self.stroke = stroke
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.jlptLevel = jlptLevel
        self.meanings = meanings
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
    
    func toSwiftDataModel() -> KanjiDataModel {
        .init(
            id: id,
            kanji: kanji,
            stroke: stroke,
            onyomi: onyomi.map { ArrayString(value: $0) },
            kunyomi: kunyomi.map { ArrayString(value: $0) },
            jlptLevel: KanjiDataModel.Level(rawValue: jlptLevel.rawValue) ?? .n5,
            meanings: meanings.map { ArrayString(value: $0) },
            dateAdded: dateAdded,
            addedIndex: addedIndex
        )
    }
}

public protocol AddKanjiUseCase {
    func execute(param: KanjiParam, progress: WordsProgressParam) throws
}

public struct DefaultAddKanjiUseCase: AddKanjiUseCase {
    let kanjiRepository: KanjiRepository
    let wordsProgressRepository: WordsProgressRepository
    
    public init(
        kanjiRepository: KanjiRepository,
        wordsProgressRepository: WordsProgressRepository
    ) {
        self.kanjiRepository = kanjiRepository
        self.wordsProgressRepository = wordsProgressRepository
    }
    
    public func execute(param: KanjiParam, progress: WordsProgressParam) throws {
        try kanjiRepository.add(param.toSwiftDataModel())
        try wordsProgressRepository.updateProgress(progress.asDataModel)
        UpdateProgressUserDefaults.update(progress)
    }
}


