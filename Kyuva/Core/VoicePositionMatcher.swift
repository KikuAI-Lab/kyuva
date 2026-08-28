import Foundation

/// The script position selected by a voice transcript.
struct VoicePositionMatch: Equatable {
    let tokenIndex: Int
    let lineIndex: Int
    /// A value from 0 (the first token) through 1 (the last token).
    let progress: Double
}

/// Matches speech transcripts to a script without allowing the position to move backwards.
///
/// Speech recognizers commonly deliver a growing partial transcript. Matching the trailing
/// normalized phrase lets each update extend the last match while keeping the matcher local to
/// the next `maxLookahead` tokens. Single-word updates are intentionally conservative: only an
/// anchor token can advance the position on its own.
struct VoicePositionMatcher {
    let tokens: [Token]
    let maxLookahead: Int

    /// The last token accepted by the matcher, or -1 before the first match.
    private(set) var currentTokenIndex: Int
    private var lastTranscriptWords: [String] = []

    init(tokens: [Token], startTokenIndex: Int = -1, maxLookahead: Int = 32) {
        self.tokens = tokens
        self.maxLookahead = max(1, maxLookahead)
        self.currentTokenIndex = Self.clampedStartIndex(startTokenIndex, tokenCount: tokens.count)
    }

    /// Reposition the matcher near a known token. The next match cannot move before it.
    mutating func reset(nearTokenIndex: Int = -1) {
        currentTokenIndex = Self.clampedStartIndex(nearTokenIndex, tokenCount: tokens.count)
        lastTranscriptWords = []
    }

    /// Feed a partial or final speech transcript and return a newly accepted position, if any.
    mutating func consume(_ transcript: String) -> VoicePositionMatch? {
        guard !tokens.isEmpty else { return nil }

        let words = Self.normalizedWords(in: transcript)
        let isDuplicatePartial = !words.isEmpty && words == lastTranscriptWords
        let isGrowingPartial = isGrowingPartialTranscript(words)
        lastTranscriptWords = words
        guard !words.isEmpty else { return nil }
        guard !isDuplicatePartial else { return nil }

        let lowerBound = max(0, currentTokenIndex)
        let upperBound = maximumReachableIndex
        guard lowerBound <= upperBound else { return nil }

        // First try the complete normalized transcript. A candidate may start just before the
        // current token when the current position falls inside a newly recognized phrase, but it
        // must always end strictly ahead of the current position.
        if words.count >= 2 {
            let completePhraseLowerBound = max(0, currentTokenIndex - words.count + 1)
            if completePhraseLowerBound <= upperBound {
                for candidateStart in completePhraseLowerBound...upperBound {
                    let candidateEnd = candidateStart + words.count - 1
                    guard candidateEnd <= upperBound, candidateEnd > currentTokenIndex else { continue }
                    guard matchesScriptPhrase(words[...], at: candidateStart, length: words.count) else {
                        continue
                    }
                    return advance(to: candidateEnd)
                }
            }
        }

        // When the recognizer extends its previous partial, match trailing phrases as well. A
        // changed/non-cumulative transcript is treated as a fresh phrase to avoid jumping on a
        // coincidental common suffix from an unrelated earlier sentence.
        if isGrowingPartial {
            for candidateStart in lowerBound...upperBound {
                let maximumPhraseLength = min(words.count - 1, upperBound - candidateStart + 1)
                guard maximumPhraseLength >= 2 else { continue }

                for phraseLength in stride(from: maximumPhraseLength, through: 2, by: -1) {
                    let speechStart = words.count - phraseLength
                    let candidateEnd = candidateStart + phraseLength - 1
                    guard candidateEnd > currentTokenIndex else { continue }
                    guard matchesScriptPhrase(
                        words[speechStart...],
                        at: candidateStart,
                        length: phraseLength
                    ) else { continue }

                    return advance(to: candidateEnd)
                }
            }
        }

        // A single recognized word is useful only when it is an intentional anchor. Use the
        // final word because earlier words in a partial transcript have already been consumed.
        guard let finalWord = words.last else { return nil }
        for candidateIndex in lowerBound...upperBound where candidateIndex > currentTokenIndex {
            let token = tokens[candidateIndex]
            if token.isAnchor && token.word == finalWord {
                return advance(to: candidateIndex)
            }
        }

        return nil
    }

    private var maximumReachableIndex: Int {
        guard !tokens.isEmpty else { return -1 }

        // Before the first match, maxLookahead counts positions from the virtual index -1.
        // Afterwards it is the maximum number of token positions ahead of the accepted token.
        guard currentTokenIndex >= 0 else {
            return min(tokens.count - 1, maxLookahead - 1)
        }
        let remainingTokens = tokens.count - 1 - currentTokenIndex
        return currentTokenIndex + min(maxLookahead, remainingTokens)
    }

    private func isGrowingPartialTranscript(_ words: [String]) -> Bool {
        guard !lastTranscriptWords.isEmpty, words.count > lastTranscriptWords.count else {
            return false
        }
        return words.starts(with: lastTranscriptWords)
    }

    private func matchesScriptPhrase(
        _ words: ArraySlice<String>,
        at startIndex: Int,
        length: Int
    ) -> Bool {
        guard words.count == length else { return false }

        for offset in 0..<length {
            guard words[words.index(words.startIndex, offsetBy: offset)] == tokens[startIndex + offset].word else {
                return false
            }
        }
        return true
    }

    private mutating func advance(to tokenIndex: Int) -> VoicePositionMatch {
        currentTokenIndex = tokenIndex
        let progress = tokens.count == 1
            ? 1
            : Double(tokenIndex) / Double(tokens.count - 1)
        return VoicePositionMatch(
            tokenIndex: tokenIndex,
            lineIndex: tokens[tokenIndex].lineIndex,
            progress: min(1, max(0, progress))
        )
    }

    private static func clampedStartIndex(_ index: Int, tokenCount: Int) -> Int {
        guard tokenCount > 0 else { return -1 }
        return min(tokenCount - 1, max(-1, index))
    }

    /// Keep this identical to Script.reindex() so transcript words and Token.word use one shape.
    private static func normalizedWords(in text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
