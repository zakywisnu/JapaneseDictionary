//
//  UpdateProgressUserDefaults.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 04/06/25.
//

import Foundation

enum UpdateProgressUserDefaults {
    static func update(_ progress: WordsProgressParam) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(progress) {
            UserDefaults.standard.set(data, forKey: "wordsProgress")
            UserDefaults.standard.synchronize()
        }
    }
}
