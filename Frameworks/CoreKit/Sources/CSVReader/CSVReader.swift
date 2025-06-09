//
//  CSVReader.swift
//  CoreKit
//
//  Created by Ahmad Zaky W on 09/05/25.
//

import Foundation

public protocol CSVReaderProtocol {
    func read(from url: URL) throws -> [[String]]
    func read(from string: String) -> [[String]]
}

public enum CSVReaderError: Error {
    case fileNotFound
    case invalidFormat
    case readError(Error)
}
