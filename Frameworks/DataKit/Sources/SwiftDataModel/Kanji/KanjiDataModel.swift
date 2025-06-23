//
//  KanjiDataModel.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 09/05/25.
//

import Foundation
import CoreKit
import SwiftData

@Model
public final class KanjiDataModel: Identifiable, CSVMappable {
    @Attribute(.unique)
    public var id: String
    public var kanji: String
    public var stroke: Int
    public var onyomi: [ArrayString]
    public var kunyomi: [ArrayString]
    public var jlptLevel: Level
    public var meanings: [ArrayString]
    public var dateAdded: Date?
    public var addedIndex: Int?
    
    public init(
        id: String,
        kanji: String,
        stroke: Int,
        onyomi: [ArrayString],
        kunyomi: [ArrayString],
        jlptLevel: Level,
        meanings: [ArrayString],
        dateAdded: Date?,
        addedIndex: Int?
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
    
    public convenience init?(csvRow: [String]) {
        guard csvRow.count >= 8 else { return nil }
        
        let id = UUID().uuidString
        let kanji = csvRow[0]
        let stroke = Int(csvRow[2]) ?? 0
        let onyomi = Self.parseArray(csvRow[4])
        let kunyomi = Self.parseArray(csvRow[5])
        var level: Int = 5
        if let doubleLevel = Double(csvRow[3]) {
            level = Int(doubleLevel)
        }
        let meanings = Self.parseArray(csvRow[6])
        
        let jlptLevel = Level(rawValue: "N\(level)") ?? .n5
        
        self.init(
            id: id,
            kanji: kanji,
            stroke: stroke,
            onyomi: onyomi.map { ArrayString(value: $0) },
            kunyomi: kunyomi.map { ArrayString(value: $0) },
            jlptLevel: jlptLevel,
            meanings: meanings.map { ArrayString(value: $0) },
            dateAdded: nil,
            addedIndex: nil
        )
    }
    
    public enum Level: String, CaseIterable, Codable {
        case n1 = "N1"
        case n2 = "N2"
        case n3 = "N3"
        case n4 = "N4"
        case n5 = "N5"
    }
    
    static func parseArray(_ str: String) -> [String] {
        let cleanStr = str
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .replacingOccurrences(of: "\'", with: "")
        return cleanStr.components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
