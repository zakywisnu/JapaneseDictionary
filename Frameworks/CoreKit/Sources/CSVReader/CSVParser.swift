
import Foundation

public protocol CSVParserProtocol {
    func parse(content: String) -> [[String]]
}

public struct CSVParser: CSVParserProtocol {
    private let delimiter: String
    
    public init(delimiter: String = ",") {
        self.delimiter = delimiter
    }
    
    public func parse(content: String) -> [[String]] {
        let rows = content.components(separatedBy: .newlines)
        return rows
            .filter { !$0.isEmpty }
            .map { $0.components(separatedBy: delimiter) }
    }
}
