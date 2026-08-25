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

    static func writeExport(
        name: String,
        content: String,
        in baseDirectory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let directory = baseDirectory
            .appendingPathComponent("Kyuva-Share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent(exportName(for: name))
        try Data(content.utf8).write(to: url, options: .atomic)
        return url
    }

    static func exportName(for name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceName = trimmedName.lowercased().hasSuffix(".txt")
            ? String(trimmedName.dropLast(4))
            : trimmedName
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
