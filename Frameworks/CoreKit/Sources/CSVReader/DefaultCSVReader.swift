import Foundation

public struct DefaultCSVReader: CSVReaderProtocol {
    private let parser: CSVParserProtocol
    
    public init(parser: CSVParserProtocol = CSVParser()) {
        self.parser = parser
    }
    
    public func read(from url: URL) throws -> [[String]] {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return read(from: content)
        } catch {
            throw CSVReaderError.readError(error)
        }
    }
    
    public func read(from string: String) -> [[String]] {
        var result: [[String]] = []
        var currentRow: [String] = []
        var currentValue = ""
        var insideQuotes = false
        
        let characters = Array(string)
        var i = 0
        
        while i < characters.count {
            let char = characters[i]
            
            switch char {
            case "\"":
                insideQuotes.toggle()
                i += 1
                continue
                
            case ",":
                if !insideQuotes {
                    currentRow.append(currentValue.trimmingCharacters(in: .whitespaces))
                    currentValue = ""
                } else {
                    currentValue += String(char)
                }
                
            case "\n", "\r\n":
                if !insideQuotes {
                    if !currentValue.isEmpty {
                        currentRow.append(currentValue.trimmingCharacters(in: .whitespaces))
                    }
                    if !currentRow.isEmpty {
                        result.append(currentRow)
                    }
                    currentRow = []
                    currentValue = ""
                } else {
                    currentValue += String(char)
                }
                
            default:
                currentValue += String(char)
            }
            
            i += 1
        }
        
        // Handle last value if exists
        if !currentValue.isEmpty {
            currentRow.append(currentValue.trimmingCharacters(in: .whitespaces))
        }
        if !currentRow.isEmpty {
            result.append(currentRow)
        }
        
        return result
    }
}
