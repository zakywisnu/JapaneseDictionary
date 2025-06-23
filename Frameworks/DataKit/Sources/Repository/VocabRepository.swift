//
//  VocabRepository.swift
//  DataKit
//
//  Created by Ahmad Zaky W on 10/05/25.
//

import Foundation
import CoreKit

public protocol VocabRepository {
    func fetchKanjiData() throws -> [KanjiDataModel]
    func fetchKotobaData() throws -> [KotobaDataModel]
    func fetchKanjiWanikaniData() throws -> [KanjiDataModel]
}

public final class StandardVocabRepository: VocabRepository {
    private let reader: CSVReaderProtocol
    private let mapper: CSVMapperProtocol
    
    public init(
        reader: CSVReaderProtocol = DefaultCSVReader(),
        mapper: CSVMapperProtocol = CSVMapper()
    ) {
        self.reader = reader
        self.mapper = mapper
    }
    
    public func fetchKanjiData() throws -> [KanjiDataModel] {
        guard let fileURL = Bundle(for: Self.self).url(forResource: "kanji_data", withExtension: "csv") else {
            throw DataError.fileNotFound
        }
        
        let csvData = try reader.read(from: fileURL)
        let filteredData = csvData.map { row in
            let data = row.dropFirst()
            let first3Data = Array(data.prefix(3))
            let droppedData = Array(data.dropFirst(4))
            return first3Data + droppedData
        }
        return mapper.map(csvData: filteredData, skipHeader: true)
    }
    
    public func fetchKotobaData() throws -> [KotobaDataModel] {
        guard let fileURL = Bundle(for: Self.self).url(forResource: "jlpt_vocab", withExtension: "csv") else {
            throw DataError.fileNotFound
        }
        
        let csvData = try reader.read(from: fileURL)
        return mapper.map(csvData: csvData, skipHeader: true)
    }
    
    public func fetchKanjiWanikaniData() throws -> [KanjiDataModel] {
        guard let fileURL = Bundle(for: Self.self).url(forResource: "kanji-wanikani", withExtension: "json") else {
            throw DataError.fileNotFound
        }
        
        let data = try Data(contentsOf: fileURL)
        
        // Parse the JSON data
        let decoder = JSONDecoder()
        let kanjiWanikaniData = try decoder.decode(KanjiWKDataResponse.self, from: data)
        let sortedKanji = kanjiWanikaniData.sorted {
            let jlptA = $0.value.jlptLevel ?? 5
            let jlptB = $1.value.jlptLevel ?? 5
            if jlptA == jlptB {
                return $0.key < $1.key
            }
            
            return jlptA < jlptB
        }
        
        return sortedKanji.compactMap { wanikaniKanji in
            
            let kanji = wanikaniKanji.key
            let valueData = wanikaniKanji.value
            let onyomi = valueData.onyomi
            let kunyomi = valueData.kunyomi
            let meanings = valueData.meanings
            
            let jlptLevel: KanjiDataModel.Level
            switch valueData.jlptLevel {
            case 5:
                jlptLevel = .n5
            case 4:
                jlptLevel = .n4
            case 3:
                jlptLevel = .n3
            case 2:
                jlptLevel = .n2
            default:
                jlptLevel = .n1
            }
            
            // Estimate stroke count based on character complexity
            // This is a rough estimation - you might want to use a more accurate method
            
            return KanjiDataModel(
                id: UUID().uuidString,
                kanji: kanji,
                stroke: valueData.strokes ?? 0,
                onyomi: onyomi?.compactMap { $0 }.map { ArrayString(value: $0) } ?? [],
                kunyomi: kunyomi?.compactMap { $0 }.map { ArrayString(value: $0) } ?? [],
                jlptLevel: jlptLevel,
                meanings: meanings?.compactMap { $0 }.map { ArrayString(value: $0) } ?? [],
                dateAdded: nil,
                addedIndex: nil
            )
        }
    }
    
    typealias KanjiWKDataResponse = [String: KanjiWKResponse]
}

struct KanjiWKResponse: Codable {
    let strokes: Int?
    let grade: Int?
    let freq: Int?
    let jlptLevel: Int?
    let meanings: [String]?
    let onyomi: [String]?
    let kunyomi: [String]?
    
    enum CodingKeys: String, CodingKey {
        case strokes = "strokes"
        case grade
        case freq
        case jlptLevel = "jlpt_new"
        case meanings
        case onyomi = "readings_on"
        case kunyomi = "readings_kun"
    }
}
