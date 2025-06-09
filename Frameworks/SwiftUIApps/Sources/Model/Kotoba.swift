//
//  Kotoba.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import Foundation
import CoreKit
import DataKit
import DomainKit

struct Kotoba: Hashable {
    var id: String
    var kanji: String
    var furigana: String
    var english: [String]
    var jlptLevel: Level
    var dateAdded: Date?
    var addedIndex: Int?
    
    enum Level: String, CaseIterable {
        case n1 = "N1"
        case n2 = "N2"
        case n3 = "N3"
        case n4 = "N4"
        case n5 = "N5"
    }
    
    var asKotobaParam: KotobaParam {
        return KotobaParam(
            id: id,
            kanji: kanji,
            furigana: furigana,
            english: english,
            jlptLevel: .init(rawValue: jlptLevel.rawValue) ?? .n5,
            dateAdded: dateAdded ?? Date(),
            addedIndex: addedIndex ?? 0
        )
    }
}

extension KotobaDataModel {
    func mapToKotoba() -> Kotoba {
        Kotoba(
            id: id,
            kanji: kanji,
            furigana: furigana,
            english: english.map { $0.value } ,
            jlptLevel: .init(rawValue: jlptLevel.rawValue) ?? .n5,
            dateAdded: dateAdded,
            addedIndex: addedIndex
        )
    }
}

extension Collection where Element == KotobaDataModel {
    func mapToKotobas() -> [Kotoba] {
        map { $0.mapToKotoba() }
    }
}
