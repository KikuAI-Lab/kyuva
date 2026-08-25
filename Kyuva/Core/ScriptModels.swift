import Foundation

struct Script: Identifiable, Codable {
    let id: UUID
    var name: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    // Derived on creation and load; these values are intentionally not persisted.
    var lines: [String] = []
    var tokens: [Token] = []

    enum CodingKeys: String, CodingKey {
        case id, name, content, createdAt, updatedAt
    }

    init(name: String, content: String) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
        reindex()
    }

    mutating func reindex() {
        lines = content
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        tokens = []
        for (lineIndex, line) in lines.enumerated() {
            let words = line
                .lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { !$0.isEmpty }

            for word in words {
                tokens.append(Token(
                    word: word,
                    lineIndex: lineIndex,
                    isAnchor: word.count > 6
                ))
            }
        }
    }
}

struct Token: Codable {
    let word: String
    let lineIndex: Int
    let isAnchor: Bool
}

struct PromptLine: Identifiable, Equatable {
    let sourceIndex: Int
    let text: String

    var id: Int { sourceIndex }

    var isStageDirection: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, let last = trimmed.last else { return false }
        return (first == "[" && last == "]") || (first == "(" && last == ")")
    }
}

extension Script {
    var promptLines: [PromptLine] {
        lines.enumerated().map { index, text in
            PromptLine(sourceIndex: index, text: text)
        }
    }

    func wordCount(excludingStageDirections: Bool) -> Int {
        promptLines
            .filter { !excludingStageDirections || !$0.isStageDirection }
            .reduce(0) { count, line in
                count + line.text.split(whereSeparator: \.isWhitespace).count
            }
    }
}
