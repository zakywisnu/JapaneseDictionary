//
//  KanjiDataModel.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 09/05/25.
//

import Foundation
import SwiftData

@Model
final class KanjiDataModel: Identifiable {
    @Attribute(.unique)
    var id: String
    var kanji: String
    var stroke: Int
    var onyomi: [String]
    var kunyomi: [String]
    var jlptLevel: Int
    var meanings: [String]
    var jpExample: String
    var enExample: String
    
    init(
        id: String,
        kanji: String,
        stroke: Int,
        onyomi: [String],
        kunyomi: [String],
        jlptLevel: Int,
        meanings: [String],
        jpExample: String,
        enExample: String
    ) {
        self.id = id
        self.kanji = kanji
        self.stroke = stroke
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.jlptLevel = jlptLevel
        self.meanings = meanings
        self.jpExample = jpExample
        self.enExample = enExample
    }
}

