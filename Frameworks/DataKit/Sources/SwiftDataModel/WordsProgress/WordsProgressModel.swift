//
//  WordsProgress.swift
//  DataKit
//
//  Created by Ahmad Zaky W on 10/05/25.
//

import Foundation
import SwiftData

@Model
public final class WordsProgressModel: Identifiable {
    @Attribute(.unique)
    public var id: String
    public var kanjiProgress: Int
    public var kotobaProgress: Int
    public var kanjiLevel: Level
    public var kotobaLevel: Level
    public var lastKotobaUpdated: Date
    public var lastKanjiUpdated: Date
    
    public init(
        id: String,
        kanjiProgress: Int,
        kotobaProgress: Int,
        kanjiLevel: Level,
        kotobaLevel: Level,
        lastKotobaUpdated: Date,
        lastKanjiUpdated: Date
    ) {
        self.id = id
        self.kanjiProgress = kanjiProgress
        self.kotobaProgress = kotobaProgress
        self.kanjiLevel = kanjiLevel
        self.kotobaLevel = kotobaLevel
        self.lastKotobaUpdated = lastKotobaUpdated
        self.lastKanjiUpdated = lastKanjiUpdated
    }
    
    public enum Level: String, CaseIterable, Codable {
        case n1 = "N1"
        case n2 = "N2"
        case n3 = "N3"
        case n4 = "N4"
        case n5 = "N5"
    }
}

