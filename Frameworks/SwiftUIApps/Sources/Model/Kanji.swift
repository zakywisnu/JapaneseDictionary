//
//  Kanji.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import Foundation
import DataKit
import DomainKit

public struct Kanji: Hashable {
    public var id: String
    public var kanji: String
    public var stroke: Int
    public var onyomi: [String]
    public var kunyomi: [String]
    public var jlptLevel: Level
    public var meanings: [String]
    public var dateAdded: Date?
    public var addedIndex: Int?
    
    public enum Level: String, CaseIterable {
        case n1 = "N1"
        case n2 = "N2"
        case n3 = "N3"
        case n4 = "N4"
        case n5 = "N5"
    }
    
    public var asKanjiParam: KanjiParam {
        return KanjiParam(
            id: id,
            kanji: kanji,
            stroke: stroke,
            onyomi: onyomi,
            kunyomi: kunyomi,
            jlptLevel: .init(rawValue: jlptLevel.rawValue) ?? .n5,
            meanings: meanings,
            dateAdded: dateAdded ?? Date(),
            addedIndex: addedIndex ?? 0
        )
    }
}

extension KanjiDataModel {
    var asKanji: Kanji {
        Kanji(
            id: id,
            kanji: kanji,
            stroke: stroke,
            onyomi: onyomi.map { $0.value },
            kunyomi: kunyomi.map { $0.value },
            jlptLevel: .init(rawValue: jlptLevel.rawValue) ?? .n5,
            meanings: meanings.map { $0.value },
            dateAdded: dateAdded,
            addedIndex: addedIndex
        )
    }
}

extension Array where Element == KanjiDataModel {
    func mapToDomain() -> [Kanji] {
        map(\.asKanji)
    }
}
