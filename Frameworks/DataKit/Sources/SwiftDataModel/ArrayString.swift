//
//  ArrayString.swift
//  DataKit
//
//  Created by Ahmad Zaky W on 02/06/25.
//

import Foundation

public struct ArrayString: Codable {
    public let value: String
    
    public init(value: String) {
        self.value = value
    }
}
