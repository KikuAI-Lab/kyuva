import Foundation
import XCTest
@testable import Kyuva

final class OnDeviceSpeechRecognizerTests: XCTestCase {
    func testLocaleSelectionExcludesSpeechLocalesWithoutOnDeviceSupport() {
        let cloudOnly = Locale(identifier: "en-AE")
        let onDevice = Locale(identifier: "en-US")
        let filtered = OnDeviceSpeechRecognizer.localesSupportingOnDeviceRecognition(
            from: [cloudOnly, onDevice]
        ) { $0 == onDevice }

        XCTAssertEqual(filtered, [onDevice])
        XCTAssertEqual(
            OnDeviceSpeechRecognizer.chooseRecognitionLocale(
                languageCode: "en",
                supportedLocales: filtered,
                preferredLanguageIdentifiers: []
            ),
            onDevice
        )
    }

    func testOnlyPreparingAndListeningStatesAreEngaged() {
        XCTAssertFalse(OnDeviceSpeechState.idle.isEngaged)
        XCTAssertTrue(OnDeviceSpeechState.requestingPermission.isEngaged)
        XCTAssertTrue(OnDeviceSpeechState.listening(localeIdentifier: "en-US").isEngaged)
        XCTAssertFalse(OnDeviceSpeechState.permissionDenied.isEngaged)
        XCTAssertFalse(OnDeviceSpeechState.unsupported(localeIdentifier: "uk-UA").isEngaged)
        XCTAssertFalse(OnDeviceSpeechState.failed.isEngaged)
    }

    func testScriptLanguageChoosesMatchingSupportedLocale() {
        let selected = OnDeviceSpeechRecognizer.chooseRecognitionLocale(
            languageCode: "uk",
            supportedLocales: [
                Locale(identifier: "en-US"),
                Locale(identifier: "uk-UA")
            ],
            preferredLanguageIdentifiers: ["en-US"]
        )

        XCTAssertEqual(selected?.identifier, "uk-UA")
    }

    func testMatchingPreferredLocaleWinsWithinOneLanguage() {
        let selected = OnDeviceSpeechRecognizer.chooseRecognitionLocale(
            languageCode: "en",
            supportedLocales: [
                Locale(identifier: "en-US"),
                Locale(identifier: "en-GB")
            ],
            preferredLanguageIdentifiers: ["en-GB", "en-US"]
        )

        XCTAssertEqual(selected?.identifier, "en-GB")
    }

    func testUnknownScriptLanguageFallsBackToPreferredSupportedLocale() {
        let selected = OnDeviceSpeechRecognizer.chooseRecognitionLocale(
            languageCode: nil,
            supportedLocales: [
                Locale(identifier: "de-DE"),
                Locale(identifier: "en-US")
            ],
            preferredLanguageIdentifiers: ["fr-FR", "en-US"]
        )

        XCTAssertEqual(selected?.identifier, "en-US")
    }

    func testDetectedUnsupportedLanguageDoesNotFallBackToAnotherLanguage() {
        let selected = OnDeviceSpeechRecognizer.chooseRecognitionLocale(
            languageCode: "ja",
            supportedLocales: [Locale(identifier: "en-US")],
            preferredLanguageIdentifiers: ["en-US"]
        )

        XCTAssertNil(selected)
    }

    func testNoSupportedLocaleReturnsNil() {
        XCTAssertNil(
            OnDeviceSpeechRecognizer.chooseRecognitionLocale(
                languageCode: "en",
                supportedLocales: [],
                preferredLanguageIdentifiers: ["en-US"]
            )
        )
    }
}
