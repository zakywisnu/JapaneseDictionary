
import Foundation

public protocol CSVMapperProtocol {
    func map<T: CSVMappable>(csvData: [[String]], skipHeader: Bool) -> [T]
}

public struct CSVMapper: CSVMapperProtocol {
    public init() {}
    
    public func map<T: CSVMappable>(csvData: [[String]], skipHeader: Bool = true) -> [T] {
        let startIndex = skipHeader ? 1 : 0
        return csvData[startIndex...].compactMap { T(csvRow: $0) }
    }
}
