//
//  VocabDataModel.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 09/05/25.
//

import Foundation
import SwiftData

@Model
final class VocabDataModel: Identifiable {
    @Attribute(.unique)
    var id: String
    var kanji: String
    var furigana: String
    var english: String
    var jlptLevel: Int
    
    init(
        id: String,
        kanji: String,
        furigana: String,
        english: String,
        jlptLevel: Int
    ) {
        self.id = id
        self.kanji = kanji
        self.furigana = furigana
        self.english = english
        self.jlptLevel = jlptLevel
    }
}
