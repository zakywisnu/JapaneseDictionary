//
//  VocabDataModel.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 09/05/25.
//

import Foundation
import SwiftData
import CoreKit

@Model
public final class KotobaDataModel: Identifiable, CSVMappable {
    
    @Attribute(.unique)
    public var id: String
    public var kanji: String
    public var furigana: String
    public var english: [ArrayString]
    public var jlptLevel: Level
    public var dateAdded: Date?
    public var addedIndex: Int?
    
    public init(
        id: String,
        kanji: String,
        furigana: String,
        english: [ArrayString],
        jlptLevel: Level,
        dateAdded: Date?,
        addedIndex: Int?
    ) {
        self.id = id
        self.kanji = kanji
        self.furigana = furigana
        self.english = english
        self.jlptLevel = jlptLevel
        self.dateAdded = dateAdded
        self.addedIndex = addedIndex
    }
    
    public convenience init?(csvRow: [String]) {
        guard csvRow.count >= 4 else { return nil }
        
        let id = UUID().uuidString
        let kanji = csvRow[0]
        let furigana = csvRow[1]
        
        // Remove quotes and split by comma-space
        let englishString = csvRow[2]
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        let meanings = englishString
            .replacingOccurrences(of: ", ", with: "|||")  // Temporary separator
            .replacingOccurrences(of: ",", with: "|||")   // Handle cases without space
            .components(separatedBy: "|||")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let jlptLevel = csvRow[3]
        
        self.init(
            id: id,
            kanji: kanji,
            furigana: furigana,
            english: meanings.map { ArrayString(value: $0) },
            jlptLevel: Level(rawValue: jlptLevel) ?? .n5,
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
}

private extension CharacterSet {
    static let quotes = CharacterSet(charactersIn: "\"'")
}
