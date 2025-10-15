//
//  KanjiRepository.swift
//  DataKit
//
//  Created by Ahmad Zaky W on 10/05/25.
//

import Foundation
import SwiftData

public protocol KanjiRepository {
    func fetchAll() throws -> [KanjiDataModel]
    func fetch(id: String) throws -> KanjiDataModel
    func add(_ param: KanjiDataModel) throws
    func update(_ param: KanjiDataModel) throws
    func delete(id: String) throws
}

public struct StandardKanjiRepository: KanjiRepository {
    let context: ModelContext
    private let serialQueue = DispatchQueue(label: "com.zeroemotion.\(Self.self)", qos: .userInitiated)
    
    public init(context: ModelContext) {
        self.context = context
    }
    
    public func fetchAll() throws -> [KanjiDataModel] {
        try serialQueue.sync {
            return try context.fetch(FetchDescriptor<KanjiDataModel>())
        }
    }
    
    public func fetch(id: String) throws -> KanjiDataModel {
        try serialQueue.sync {
            let descriptor = getDescriptor(with: id)
            guard let data = try context.fetch(descriptor).first else {
                throw DataError.dataNotFound
            }
            return data
        }
    }
    
    public func add(_ param: KanjiDataModel) throws {
        try serialQueue.sync {
            context.insert(param)
            try context.save()
        }
    }
    
    public func update(_ param: KanjiDataModel) throws {
        try serialQueue.sync {
            let descriptor = getDescriptor(with: param.id)
            if let data = try context.fetch(descriptor).first {
                data.jlptLevel = param.jlptLevel
                data.kanji = param.kanji
                data.kunyomi = param.kunyomi
                data.meanings = param.meanings
                data.onyomi = param.onyomi
                data.stroke = param.stroke
                try context.save()
            } else {
                throw DataError.dataNotFound
            }
        }
    }
    
    public func delete(id: String) throws {
        try serialQueue.sync {
            let descriptor = getDescriptor(with: id)
            if let data = try context.fetch(descriptor).first {
                context.delete(data)
                try context.save()
            } else {
                throw DataError.dataNotFound
            }
        }
    }
    
    private func getDescriptor(with id: String) -> FetchDescriptor<KanjiDataModel> {
        return FetchDescriptor<KanjiDataModel>(
            predicate: #Predicate { $0.id == id }
        )
    }
}
