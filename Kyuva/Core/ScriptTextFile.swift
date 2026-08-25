import Foundation

enum ScriptTextImportError: Error, LocalizedError {
    case noFile
    case fileTooLarge
    case notUTF8

    var errorDescription: String? {
        switch self {
        case .noFile:
            return "No text file was selected."
        case .fileTooLarge:
            return "Choose a text file up to 1 MB."
        case .notUTF8:
            return "Kyuva can import UTF-8 plain-text files only."
        }
    }
}

enum ScriptTextFile {
    static let maximumBytes = 1_048_576

    static func exportName(for name: String) -> String {
        let sourceName = name.lowercased().hasSuffix(".txt")
            ? String(name.dropLast(4))
            : name
        let disallowed = CharacterSet.controlCharacters
            .union(CharacterSet(charactersIn: "/:"))
        let cleaned = sourceName
            .components(separatedBy: disallowed)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = cleaned.isEmpty ? "Kyuva Script" : String(cleaned.prefix(80))
        return "\(baseName).txt"
    }

    static func decodeImport(_ data: Data) throws -> String {
        guard data.count <= maximumBytes else {
            throw ScriptTextImportError.fileTooLarge
        }
        guard let content = String(data: data, encoding: .utf8) else {
            throw ScriptTextImportError.notUTF8
        }
        return content
    }
}
