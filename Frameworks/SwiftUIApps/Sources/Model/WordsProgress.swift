//
//  WordsProgress.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import Foundation
import DomainKit
import DataKit
import ZeroDesignKit

public struct WordsProgress: Codable {
    public var id: String
    public var kanjiProgress: Int
    public var kotobaProgress: Int
    public var kanjiLevel: Level
    public var kotobaLevel: Level
    public var lastKotobaUpdated: Date
    public var lastKanjiUpdated: Date
    public var kanjiIndex: Int
    public var kotobaIndex: Int
    
    public enum Level: String, CaseIterable, Codable {
        case n1 = "N1"
        case n2 = "N2"
        case n3 = "N3"
        case n4 = "N4"
        case n5 = "N5"
    }
    
    public var getKotobaProgress: String {
        kotobaLevel.rawValue
    }
    
    public var getKanjiProgress: String {
        kanjiLevel.rawValue
    }
    
    public var kotobaLatestUpdated: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: lastKotobaUpdated)
    }
    
    public var kanjiLatestUpdated: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: lastKanjiUpdated)
    }
    
    public func mapToContent(totalKotoba: Int, totalKanji: Int) -> [ContentGridData] {
        let contents: [ContentGridData] = [
            ContentGridData(
                icon: "character.textbox",
                iconColor: .green,
                label: "Kotoba",
                primaryText: "\(kotobaProgress)",
                backgroundColor: .green.opacity(0.2),
                bottomType: .level(
                    currentProgress: Double(kotobaProgress),
                    maxProgress: Double(totalKotoba),
                    label: "\(totalKotoba)",
                    color: .black
                )
            ),
            ContentGridData(
                icon: "character.magnify",
                iconColor: .red,
                label: "Kanji",
                primaryText: "\(kanjiProgress)",
                backgroundColor: .red.opacity(0.2),
                bottomType: .level(
                    currentProgress: Double(kanjiProgress),
                    maxProgress: Double(totalKanji),
                    label: "\(totalKanji)",
                    color: .black
                )
            ),
            ContentGridData(
                icon: "flame.fill",
                iconColor: .yellow,
                label: "Kotoba",
                primaryText: getKotobaProgress,
                backgroundColor: .yellow.opacity(0.2),
                bottomType: .metrics(
                    icon: .init(systemName: "calendar.badge.clock"),
                    label: "\(kotobaLatestUpdated)",
                    color: .black
                )
            ),
            ContentGridData(
                icon: "flame.fill",
                iconColor: .orange,
                label: "Kanji",
                primaryText: getKanjiProgress,
                backgroundColor: .orange.opacity(0.2),
                bottomType: .metrics(
                    icon: .init(systemName: "calendar.badge.clock"),
                    label: "\(kanjiLatestUpdated)",
                    color: .black
                )
            )
        ]
        return contents
    }
}

public extension WordsProgressModel {
    func mapToDomain() -> WordsProgress {
        return WordsProgress(
            id: id,
            kanjiProgress: kanjiProgress,
            kotobaProgress: kotobaProgress,
            kanjiLevel: .init(rawValue: kanjiLevel.rawValue) ?? .n5,
            kotobaLevel: .init(rawValue: kotobaLevel.rawValue) ?? .n5,
            lastKotobaUpdated: lastKotobaUpdated,
            lastKanjiUpdated: lastKanjiUpdated,
            kanjiIndex: kanjiIndex,
            kotobaIndex: kotobaIndex
        )
    }
}

public extension Collection where Element == WordsProgressModel {
    func mapToDomain() -> [WordsProgress] {
        return map { $0.mapToDomain() }
    }
}
