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
}

/*
Example CSV formats:

kanji_data.csv:
id,kanji,stroke,onyomi,kunyomi,jlpt_level,meanings,jp_example,en_example
k1,日,3,ニチ;ジツ,ひ;-び;-か,5,day;sun;Japan,今日はいい天気です,Today is good weather

jlpt_vocab.csv:
id,kanji,furigana,english,jlpt_level
v1,今日,きょう,today,5
v2,天気,てんき,weather,5
*/
