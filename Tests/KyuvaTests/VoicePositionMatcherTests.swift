import XCTest
@testable import Kyuva

final class VoicePositionMatcherTests: XCTestCase {
    func testMatchesPunctuationAndCaseUsingEnglishWords() throws {
        let script = Script(name: "English", content: "Hello, brave Kyuva teleprompter!")
        var matcher = VoicePositionMatcher(tokens: script.tokens)

        let match = try XCTUnwrap(matcher.consume("HELLO — BRAVE, KYUVA"))

        XCTAssertEqual(match.tokenIndex, 2)
        XCTAssertEqual(match.lineIndex, 0)
        XCTAssertEqual(match.progress, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testMatchesUkrainianCyrillicAndPunctuation() throws {
        let script = Script(name: "Ukrainian", content: "Привіт, світе! Це телесуфлер.")
        var matcher = VoicePositionMatcher(tokens: script.tokens)

        let match = try XCTUnwrap(matcher.consume("ПРИВІТ — СВІТЕ! ЦЕ"))

        XCTAssertEqual(match.tokenIndex, 2)
        XCTAssertEqual(match.lineIndex, 0)
        XCTAssertEqual(match.progress, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testGrowingPartialTranscriptsAdvanceFromTheTrailingPhrase() throws {
        let script = Script(name: "Partials", content: "Welcome to the Kyuva teleprompter")
        var matcher = VoicePositionMatcher(tokens: script.tokens)

        XCTAssertEqual(try XCTUnwrap(matcher.consume("Welcome to the")).tokenIndex, 2)
        XCTAssertEqual(
            try XCTUnwrap(matcher.consume("Welcome to the Kyuva")).tokenIndex,
            3
        )
        XCTAssertEqual(
            try XCTUnwrap(matcher.consume("Welcome to the Kyuva teleprompter")).tokenIndex,
            4
        )
        XCTAssertEqual(matcher.currentTokenIndex, 4)
    }

    func testRepeatedPhraseChoosesNearestForwardOccurrenceAcrossSegments() throws {
        let script = Script(name: "Repeated", content: "Start, take the stage. Later, take the stage.")
        var matcher = VoicePositionMatcher(tokens: script.tokens)

        let first = try XCTUnwrap(matcher.consume("TAKE THE STAGE"))
        XCTAssertNil(matcher.consume("take the stage"), "Duplicate callbacks must not advance")
        XCTAssertNil(matcher.consume(""), "An empty callback starts a fresh recognition segment")
        let second = try XCTUnwrap(matcher.consume("take the stage"))

        XCTAssertEqual(first.tokenIndex, 3)
        XCTAssertEqual(second.tokenIndex, 7)
    }

    func testNoMatchCanMoveBackwards() throws {
        let script = Script(name: "Forward", content: "First clear phrase. Then another clear phrase.")
        var matcher = VoicePositionMatcher(tokens: script.tokens)

        let later = try XCTUnwrap(matcher.consume("another clear phrase"))
        XCTAssertNil(matcher.consume("first clear phrase"))
        XCTAssertEqual(matcher.currentTokenIndex, later.tokenIndex)
    }

    func testLookaheadBoundsExactPhraseAndAnchorFallback() {
        let script = Script(name: "Bounded", content: "One two three four five six extraordinary")
        var matcher = VoicePositionMatcher(tokens: script.tokens, maxLookahead: 3)

        XCTAssertNil(matcher.consume("five six extraordinary"))
        XCTAssertNil(matcher.consume("extraordinary"))
        XCTAssertEqual(matcher.currentTokenIndex, -1)
    }

    func testAnchorWordCanAdvanceOnItsOwn() throws {
        let script = Script(name: "Anchor", content: "Start with a teleprompter")
        var matcher = VoicePositionMatcher(tokens: script.tokens)

        let match = try XCTUnwrap(matcher.consume("TELEPROMPTER"))

        XCTAssertEqual(match.tokenIndex, 3)
        XCTAssertEqual(match.lineIndex, 0)
    }

    func testCommonSingleWordDoesNotAdvance() {
        let script = Script(name: "Common", content: "Start with a camera")
        var matcher = VoicePositionMatcher(tokens: script.tokens)

        XCTAssertNil(matcher.consume("with"))
        XCTAssertEqual(matcher.currentTokenIndex, -1)
    }

    func testEmptyAndNoMatchLeaveStateUntouched() {
        let script = Script(name: "No match", content: "A small script")
        var matcher = VoicePositionMatcher(tokens: script.tokens)

        XCTAssertNil(matcher.consume("   !!!"))
        XCTAssertNil(matcher.consume("unrelated words"))
        XCTAssertEqual(matcher.currentTokenIndex, -1)

        var emptyMatcher = VoicePositionMatcher(tokens: [])
        XCTAssertNil(emptyMatcher.consume("anything"))
        XCTAssertEqual(emptyMatcher.currentTokenIndex, -1)
    }

    func testResetNearKnownTokenPreventsBackwardMovement() throws {
        let script = Script(name: "Reset", content: "First line.\nSecond line is ready.\nFinal line.")
        var matcher = VoicePositionMatcher(tokens: script.tokens, startTokenIndex: 3)

        XCTAssertNil(matcher.consume("first line"))
        let match = try XCTUnwrap(matcher.consume("second line is"))
        XCTAssertEqual(match.tokenIndex, 4)
        XCTAssertEqual(match.lineIndex, 1)

        matcher.reset(nearTokenIndex: 0)
        XCTAssertEqual(try XCTUnwrap(matcher.consume("first line")).tokenIndex, 1)
    }

    func testEndTokenReportsFullProgress() throws {
        let script = Script(name: "End", content: "The final teleprompter")
        var matcher = VoicePositionMatcher(tokens: script.tokens)

        let match = try XCTUnwrap(matcher.consume("the final teleprompter"))

        XCTAssertEqual(match.tokenIndex, 2)
        XCTAssertEqual(match.progress, 1, accuracy: 0.0001)
    }

    func testSingleTokenScriptReportsFullProgress() throws {
        let script = Script(name: "Single", content: "Teleprompter")
        var matcher = VoicePositionMatcher(tokens: script.tokens)

        let match = try XCTUnwrap(matcher.consume("teleprompter"))

        XCTAssertEqual(match.tokenIndex, 0)
        XCTAssertEqual(match.progress, 1, accuracy: 0.0001)
    }
}
