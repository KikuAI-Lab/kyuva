import XCTest
@testable import Kyuva

final class ScriptTests: XCTestCase {
    func testReindexFiltersBlankLinesAndKeepsTokenLineIndexes() {
        var script = Script(
            name: "Token fixture",
            content: "Hello, WORLD!\n\nSwiftUI's camera-side text.\nKyuva"
        )

        XCTAssertEqual(script.lines, [
            "Hello, WORLD!",
            "SwiftUI's camera-side text.",
            "Kyuva"
        ])
        XCTAssertEqual(script.tokens.map(\.word), [
            "hello", "world", "swiftui", "s", "camera", "side", "text", "kyuva"
        ])
        XCTAssertEqual(script.tokens.map(\.lineIndex), [0, 0, 1, 1, 1, 1, 1, 2])
        XCTAssertEqual(script.tokens.filter(\.isAnchor).map(\.word), ["swiftui"])

        script.content = "Updated line\n\nSecond updated line"
        script.reindex()

        XCTAssertEqual(script.lines, ["Updated line", "Second updated line"])
        XCTAssertEqual(script.tokens.map(\.word), ["updated", "line", "second", "updated", "line"])
        XCTAssertEqual(script.tokens.map(\.lineIndex), [0, 0, 1, 1, 1])
    }

    func testPromptLinesRecognizeOnlyCompleteBracketedDirections() {
        let script = Script(
            name: "Directions",
            content: "Opening line\n[Smile at camera]\n(Pause)\n[unfinished\nClosing line"
        )

        XCTAssertEqual(script.promptLines.map(\.text), [
            "Opening line",
            "[Smile at camera]",
            "(Pause)",
            "[unfinished",
            "Closing line"
        ])
        XCTAssertEqual(
            script.promptLines.map(\.isStageDirection),
            [false, true, true, false, false]
        )
        XCTAssertEqual(script.wordCount(excludingStageDirections: false), 9)
        XCTAssertEqual(script.wordCount(excludingStageDirections: true), 5)
    }
}

final class LocalStoreTests: XCTestCase {
    func testScriptsRoundTripThroughInjectedDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let queue = DispatchQueue(label: "com.kyuva.tests.local-store")
        let store = LocalStore(directoryURL: directory, saveQueue: queue)
        let script = Script(name: "Round trip", content: "First line\nSecond line")

        store.saveScripts([script])
        store.waitForPendingWrites()

        let loaded = store.loadScripts()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, script.id)
        XCTAssertEqual(loaded.first?.name, script.name)
        XCTAssertEqual(loaded.first?.content, script.content)
        XCTAssertEqual(loaded.first?.lines, script.lines)
        XCTAssertEqual(loaded.first?.tokens.map(\.word), script.tokens.map(\.word))
    }

    func testCorruptPrimaryRecoversLastKnownGoodBackupAndPreservesEvidence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(
            directoryURL: directory,
            saveQueue: DispatchQueue(label: "com.kyuva.tests.recovery-store")
        )
        let lastKnownGood = Script(name: "Recover me", content: "Important local script")
        let newer = Script(name: "Newer", content: "A later valid revision")

        store.saveScripts([lastKnownGood])
        store.waitForPendingWrites()
        store.saveScripts([newer])
        store.waitForPendingWrites()

        let primaryURL = directory.appendingPathComponent("scripts.json")
        try Data("not valid JSON".utf8).write(to: primaryURL, options: .atomic)

        let recovered = store.loadScripts()
        XCTAssertEqual(recovered.map(\.id), [lastKnownGood.id])
        XCTAssertEqual(recovered.map(\.content), [lastKnownGood.content])

        let preservedFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("scripts.corrupt-") }
        XCTAssertEqual(preservedFiles.count, 1)
        XCTAssertEqual(try Data(contentsOf: preservedFiles[0]), Data("not valid JSON".utf8))
    }
}

final class ScriptManagerPersistenceTests: XCTestCase {
    func testFlushPendingSavePersistsTheLatestDebouncedEdit() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(
            directoryURL: directory,
            saveQueue: DispatchQueue(label: "com.kyuva.tests.manager-store")
        )
        let manager = ScriptManager(storage: store)
        let scriptId = try XCTUnwrap(manager.selectedScriptId)

        manager.updateScriptName(scriptId, name: "Final name")
        manager.updateScriptContent(scriptId, content: "The final unslept edit")
        manager.flushPendingSave()

        let reloaded = LocalStore(directoryURL: directory).loadScripts()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.name, "Final name")
        XCTAssertEqual(reloaded.first?.content, "The final unslept edit")
    }
}

final class ScrollControllerTests: XCTestCase {
    func testSavedScrollSpeedAppliesAtStartupAndWhenDefaultsChange() {
        let suiteName = "KyuvaTests.ScrollController.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(72.5, forKey: "scrollSpeed")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScrollController(startTimer: false, userDefaults: defaults)
        XCTAssertEqual(controller.scrollSpeed, 72.5, accuracy: 0.0001)
        XCTAssertEqual(controller.scrollOffset, 0)

        defaults.set(118.25, forKey: "scrollSpeed")
        controller.applyPersistedScrollSpeed(from: defaults)

        XCTAssertEqual(controller.scrollSpeed, 118.25, accuracy: 0.0001)
        XCTAssertEqual(controller.scrollOffset, 0)

        controller.adjustSpeed(delta: 200)
        XCTAssertEqual(controller.scrollSpeed, ScrollController.maximumSpeed)
        XCTAssertEqual(defaults.double(forKey: "scrollSpeed"), ScrollController.maximumSpeed)

        controller.adjustSpeed(delta: -500)
        XCTAssertEqual(controller.scrollSpeed, ScrollController.minimumSpeed)
        XCTAssertEqual(defaults.double(forKey: "scrollSpeed"), ScrollController.minimumSpeed)
    }

    func testWordsPerMinuteDerivesSpeedProgressAndRemainingTime() {
        let suiteName = "KyuvaTests.ScrollController.WPM.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(ScrollPaceMode.wordsPerMinute.rawValue, forKey: ScrollController.paceModeDefaultsKey)
        defaults.set(120, forKey: ScrollController.wordsPerMinuteDefaultsKey)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScrollController(startTimer: false, userDefaults: defaults)
        controller.updateContentMetrics(contentHeight: 1_150, visibleHeight: 150, wordCount: 200)

        XCTAssertEqual(controller.paceMode, .wordsPerMinute)
        XCTAssertEqual(controller.scrollSpeed, 10, accuracy: 0.0001)
        XCTAssertEqual(controller.remainingTime ?? -1, 100, accuracy: 0.0001)
        XCTAssertEqual(controller.paceControlLabel, "120w")

        controller.goToOffset(250)
        XCTAssertEqual(controller.progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(controller.remainingTime ?? -1, 75, accuracy: 0.0001)

        controller.adjustPace(steps: 2)
        XCTAssertEqual(controller.wordsPerMinute, 130, accuracy: 0.0001)
        XCTAssertEqual(defaults.double(forKey: ScrollController.wordsPerMinuteDefaultsKey), 130)
        XCTAssertEqual(controller.scrollSpeed, 10.833_333, accuracy: 0.0001)
    }

    func testApplyingDefaultsSwitchesPaceModeWithoutMovingTheScript() {
        let suiteName = "KyuvaTests.ScrollController.ModeSwitch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(50, forKey: ScrollController.speedDefaultsKey)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScrollController(startTimer: false, userDefaults: defaults)
        controller.updateContentMetrics(contentHeight: 1_150, visibleHeight: 150, wordCount: 200)
        controller.goToOffset(250)

        defaults.set(ScrollPaceMode.wordsPerMinute.rawValue, forKey: ScrollController.paceModeDefaultsKey)
        defaults.set(120, forKey: ScrollController.wordsPerMinuteDefaultsKey)
        controller.applyPersistedScrollSpeed(from: defaults)

        XCTAssertEqual(controller.paceMode, .wordsPerMinute)
        XCTAssertEqual(controller.scrollSpeed, 10, accuracy: 0.0001)
        XCTAssertEqual(controller.scrollOffset, 250)
    }

    func testTargetDurationDerivesSpeedAndFasterControlShortensDuration() {
        let suiteName = "KyuvaTests.ScrollController.Duration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(ScrollPaceMode.targetDuration.rawValue, forKey: ScrollController.paceModeDefaultsKey)
        defaults.set(120, forKey: ScrollController.targetDurationDefaultsKey)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScrollController(startTimer: false, userDefaults: defaults)
        controller.updateContentMetrics(contentHeight: 750, visibleHeight: 150, wordCount: 100)

        XCTAssertEqual(controller.paceMode, .targetDuration)
        XCTAssertEqual(controller.scrollSpeed, 5, accuracy: 0.0001)
        XCTAssertEqual(controller.remainingTime ?? -1, 120, accuracy: 0.0001)
        XCTAssertEqual(controller.paceControlLabel, "2:00")

        controller.goToOffset(150)
        XCTAssertEqual(controller.progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(controller.remainingTime ?? -1, 90, accuracy: 0.0001)

        controller.adjustPace(steps: 1)
        XCTAssertEqual(controller.targetDurationSeconds, 90, accuracy: 0.0001)
        XCTAssertEqual(defaults.double(forKey: ScrollController.targetDurationDefaultsKey), 90)
        XCTAssertEqual(controller.scrollSpeed, 6.666_667, accuracy: 0.0001)
    }
}

final class HotkeyDefinitionTests: XCTestCase {
    func testFixedHotkeysHaveUniqueSystemDefinitions() {
        let shortcuts = HotkeyManager.Hotkey.allCases.map(\.shortcut)
        let systemDefinitions = shortcuts.map { "\($0.keyCode)-\($0.modifiers)" }

        XCTAssertEqual(Set(systemDefinitions).count, shortcuts.count)
        XCTAssertEqual(HotkeyManager.Hotkey.togglePause.shortcut.display, "⌃⌥Space")
    }
}
