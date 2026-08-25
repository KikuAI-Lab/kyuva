import Network
import XCTest
@testable import Kyuva

final class ScriptTextFileTests: XCTestCase {
    func testExportNameIsSafeBoundedAndKeepsOneTextExtension() {
        XCTAssertEqual(
            ScriptTextFile.exportName(for: "  Scene/Take:One  .TXT"),
            "Scene-Take-One.txt"
        )
        XCTAssertEqual(ScriptTextFile.exportName(for: "   "), "Kyuva Script.txt")

        let longName = ScriptTextFile.exportName(for: String(repeating: "a", count: 120))
        XCTAssertEqual(longName, String(repeating: "a", count: 80) + ".txt")
    }

    func testDecodeImportAcceptsTheExactByteLimit() throws {
        let data = Data(repeating: 0x61, count: ScriptTextFile.maximumBytes)

        let content = try ScriptTextFile.decodeImport(data)

        XCTAssertEqual(content.utf8.count, ScriptTextFile.maximumBytes)
    }

    func testDecodeImportRejectsOneByteOverTheLimit() {
        let data = Data(repeating: 0x61, count: ScriptTextFile.maximumBytes + 1)

        XCTAssertThrowsError(try ScriptTextFile.decodeImport(data)) { error in
            guard case ScriptTextImportError.fileTooLarge = error else {
                return XCTFail("Expected fileTooLarge, got \(error)")
            }
        }
    }

    func testDecodeImportRejectsInvalidUTF8() {
        XCTAssertThrowsError(try ScriptTextFile.decodeImport(Data([0xC3, 0x28]))) { error in
            guard case ScriptTextImportError.notUTF8 = error else {
                return XCTFail("Expected notUTF8, got \(error)")
            }
        }
    }
}

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
    func testCreateAndDeleteKeepAValidSelectionAndPersist() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaCRUDTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(
            directoryURL: directory,
            saveQueue: DispatchQueue(label: "com.kyuva.tests.crud-store")
        )
        let manager = ScriptManager(storage: store)
        let originalId = try XCTUnwrap(manager.selectedScriptId)

        manager.createNewScript()
        let createdId = try XCTUnwrap(manager.selectedScriptId)
        XCTAssertNotEqual(createdId, originalId)
        XCTAssertEqual(manager.scripts.count, 2)

        let createdIndex = try XCTUnwrap(
            manager.scripts.firstIndex(where: { $0.id == createdId })
        )
        manager.deleteScripts(at: IndexSet(integer: createdIndex))
        manager.flushPendingSave()

        XCTAssertEqual(manager.scripts.map(\.id), [originalId])
        XCTAssertEqual(manager.selectedScriptId, originalId)
        XCTAssertEqual(LocalStore(directoryURL: directory).loadScripts().map(\.id), [originalId])
    }

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

    func testImportCreatesSelectsAndPersistsOneScript() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(
            directoryURL: directory,
            saveQueue: DispatchQueue(label: "com.kyuva.tests.import-store")
        )
        let manager = ScriptManager(storage: store)

        let imported = manager.importScript(name: "  AirDrop Notes  ", content: "First\nSecond")
        manager.flushPendingSave()

        XCTAssertEqual(imported.name, "AirDrop Notes")
        XCTAssertEqual(manager.selectedScriptId, imported.id)
        XCTAssertEqual(manager.scripts.last?.id, imported.id)
        XCTAssertEqual(manager.scripts.last?.content, imported.content)
        let reloaded = LocalStore(directoryURL: directory).loadScripts().last
        XCTAssertEqual(reloaded?.id, imported.id)
        XCTAssertEqual(reloaded?.content, imported.content)
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
        XCTAssertEqual(HotkeyManager.Hotkey.nextDisplay.shortcut.display, "⌃⌥D")
    }
}

final class WindowDragTrackerTests: XCTestCase {
    func testCumulativeGestureTranslationUsesTheOriginalWindowOrigin() {
        var tracker = WindowDragTracker()
        let start = CGPoint(x: 100, y: 200)

        let first = tracker.origin(
            currentOrigin: start,
            translation: CGPoint(x: 10, y: 5)
        )
        XCTAssertEqual(first, CGPoint(x: 110, y: 195))

        let second = tracker.origin(
            currentOrigin: first,
            translation: CGPoint(x: 20, y: 10)
        )
        XCTAssertEqual(second, CGPoint(x: 120, y: 190))

        tracker.reset()
        let nextGesture = tracker.origin(
            currentOrigin: second,
            translation: CGPoint(x: 5, y: 5)
        )
        XCTAssertEqual(nextGesture, CGPoint(x: 125, y: 185))
    }
}

final class RemoteControlProtocolTests: XCTestCase {
    func testCommandsRoundTripThroughPropertyListMessage() {
        for command in RemoteCommand.allCases {
            XCTAssertEqual(RemoteCommand(message: command.message), command)
        }

        XCTAssertNil(RemoteCommand(message: [:]))
        XCTAssertNil(RemoteCommand(message: ["command": "unknown"] as [String: Any]))
    }

    func testPlaybackSnapshotRoundTripsAndClampsProgress() throws {
        let snapshot = PlaybackSnapshot(
            isPromptActive: true,
            isPaused: false,
            scriptTitle: "Keynote",
            paceLabel: "150w",
            progress: 1.4
        )

        XCTAssertEqual(snapshot.progress, 1)
        XCTAssertEqual(PlaybackSnapshot(message: snapshot.message), snapshot)
        XCTAssertNil(PlaybackSnapshot(message: ["isPaused": true] as [String: Any]))
    }
}

final class LocalRemoteSecurityTests: XCTestCase {
    func testPairingCodeUsesExactlyEightyBitsOfBase32Characters() throws {
        let bytes = Array(UInt8(0)...UInt8(15))
        let code = LocalRemoteSecurity.pairingCode(from: bytes)

        XCTAssertEqual(code.count, 16)
        XCTAssertEqual(code, "23456789ABCDEFGH")
        XCTAssertTrue(code.allSatisfy(LocalRemoteSecurity.pairingAlphabet.contains))
        XCTAssertEqual(
            try LocalRemoteSecurity.normalizedPairingCode("2345-6789 abcd-efgh"),
            code
        )
        XCTAssertEqual(LocalRemoteSecurity.formattedPairingCode(code), "2345-6789-ABCD-EFGH")
    }

    func testPairingCodeRejectsWrongLengthAndAmbiguousCharacters() {
        XCTAssertThrowsError(try LocalRemoteSecurity.normalizedPairingCode("2345"))
        XCTAssertThrowsError(try LocalRemoteSecurity.normalizedPairingCode("2345-6789-ABCD-EFGI"))
        XCTAssertThrowsError(try LocalRemoteSecurity.normalizedPairingCode("2345-6789-ABCD-EFG0"))
    }

    func testKeyDerivationIsStableAndCodeSpecific() throws {
        let first = try LocalRemoteSecurity.derivedKey(for: "2345-6789-ABCD-EFGH")
        let normalized = try LocalRemoteSecurity.derivedKey(for: "23456789abcdefgh")
        let second = try LocalRemoteSecurity.derivedKey(for: "3456-789A-BCDE-FGHJ")

        XCTAssertEqual(first.count, 32)
        XCTAssertEqual(first, normalized)
        XCTAssertNotEqual(first, second)
        XCTAssertNoThrow(try LocalRemoteSecurity.parameters(pairingCode: "23456789ABCDEFGH"))
    }

    func testMatchingTLSPSKCompletesLoopbackHandshake() throws {
        let serverParameters = try LocalRemoteSecurity.parameters(
            pairingCode: "23456789ABCDEFGH"
        )
        let clientParameters = try LocalRemoteSecurity.parameters(
            pairingCode: "23456789ABCDEFGH"
        )
        let listener = try NWListener(using: serverParameters, on: .any)
        let queue = DispatchQueue(label: "com.kyuva.tests.tls-matching")
        let listenerReady = expectation(description: "listener ready")
        let serverConnectionReady = expectation(description: "server TLS ready")
        let clientConnectionReady = expectation(description: "client TLS ready")
        var serverConnection: NWConnection?
        var clientConnection: NWConnection?

        listener.newConnectionHandler = { connection in
            serverConnection = connection
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    serverConnectionReady.fulfill()
                }
            }
            connection.start(queue: queue)
        }
        listener.stateUpdateHandler = { state in
            guard case .ready = state, let port = listener.port else { return }
            listenerReady.fulfill()
            let connection = NWConnection(
                host: .ipv4(IPv4Address.loopback),
                port: port,
                using: clientParameters
            )
            clientConnection = connection
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    clientConnectionReady.fulfill()
                }
            }
            connection.start(queue: queue)
        }
        listener.start(queue: queue)

        wait(
            for: [listenerReady, serverConnectionReady, clientConnectionReady],
            timeout: 5,
            enforceOrder: false
        )
        clientConnection?.cancel()
        serverConnection?.cancel()
        listener.cancel()
    }

    func testMismatchedTLSPSKCannotCompleteLoopbackHandshake() throws {
        let serverParameters = try LocalRemoteSecurity.parameters(
            pairingCode: "23456789ABCDEFGH"
        )
        let clientParameters = try LocalRemoteSecurity.parameters(
            pairingCode: "3456789ABCDEFGHJ"
        )
        let listener = try NWListener(using: serverParameters, on: .any)
        let queue = DispatchQueue(label: "com.kyuva.tests.tls-mismatch")
        let unexpectedReady = expectation(description: "mismatched TLS never ready")
        unexpectedReady.isInverted = true
        var serverConnection: NWConnection?
        var clientConnection: NWConnection?

        listener.newConnectionHandler = { connection in
            serverConnection = connection
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    unexpectedReady.fulfill()
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
        listener.stateUpdateHandler = { state in
            guard case .ready = state, let port = listener.port else { return }
            let connection = NWConnection(
                host: .ipv4(IPv4Address.loopback),
                port: port,
                using: clientParameters
            )
            clientConnection = connection
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    unexpectedReady.fulfill()
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
        listener.start(queue: queue)

        wait(for: [unexpectedReady], timeout: 1, enforceOrder: false)
        clientConnection?.cancel()
        serverConnection?.cancel()
        listener.cancel()
    }
}

final class LocalRemoteProtocolTests: XCTestCase {
    private let snapshot = PlaybackSnapshot(
        isPromptActive: true,
        isPaused: false,
        scriptTitle: "Launch notes",
        paceLabel: "150w",
        progress: 0.42
    )

    func testEveryCommandRoundTripsWithVersionAndSequence() throws {
        for (index, command) in RemoteCommand.allCases.enumerated() {
            let request = LocalRemoteRequest(sequence: UInt64(index + 1), command: command)
            let data = try LocalRemoteProtocol.encode(request)

            XCTAssertLessThanOrEqual(data.count, LocalRemoteProtocol.maximumMessageBytes)
            XCTAssertEqual(
                try LocalRemoteProtocol.decodeRequest(data, after: UInt64(index)),
                request
            )
        }
    }

    func testRequestRejectsUnknownWrongVersionAndReplay() throws {
        let valid = LocalRemoteRequest(sequence: 2, command: .togglePlayback)
        let validData = try LocalRemoteProtocol.encode(valid)
        let unknownField = Data(
            "{\"command\":\"togglePlayback\",\"extra\":true,\"sequence\":2,\"version\":1}".utf8
        )
        let unknownCommand = Data(
            "{\"command\":\"deleteScript\",\"sequence\":2,\"version\":1}".utf8
        )
        let wrongVersion = Data(
            "{\"command\":\"togglePlayback\",\"sequence\":2,\"version\":99}".utf8
        )

        XCTAssertThrowsError(try LocalRemoteProtocol.decodeRequest(unknownField, after: 0)) {
            XCTAssertEqual($0 as? LocalRemoteProtocolError, .unknownField)
        }
        XCTAssertThrowsError(try LocalRemoteProtocol.decodeRequest(unknownCommand, after: 0)) {
            XCTAssertEqual($0 as? LocalRemoteProtocolError, .malformedMessage)
        }
        XCTAssertThrowsError(try LocalRemoteProtocol.decodeRequest(wrongVersion, after: 0)) {
            XCTAssertEqual($0 as? LocalRemoteProtocolError, .unsupportedVersion)
        }
        XCTAssertThrowsError(try LocalRemoteProtocol.decodeRequest(validData, after: 2)) {
            XCTAssertEqual($0 as? LocalRemoteProtocolError, .replayedSequence)
        }
    }

    func testResponseRoundTripsAndRejectsMismatchOrNestedUnknownField() throws {
        let response = LocalRemoteResponse(sequence: 7, result: .ok, snapshot: snapshot)
        let data = try LocalRemoteProtocol.encode(response)

        XCTAssertEqual(
            try LocalRemoteProtocol.decodeResponse(data, expectedSequence: 7),
            response
        )
        XCTAssertThrowsError(try LocalRemoteProtocol.decodeResponse(data, expectedSequence: 8)) {
            XCTAssertEqual($0 as? LocalRemoteProtocolError, .mismatchedResponse)
        }

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var nested = try XCTUnwrap(object["snapshot"] as? [String: Any])
        nested["scriptContent"] = "must never travel"
        object["snapshot"] = nested
        let contaminated = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(
            try LocalRemoteProtocol.decodeResponse(contaminated, expectedSequence: 7)
        ) {
            XCTAssertEqual($0 as? LocalRemoteProtocolError, .unknownField)
        }
    }

    func testResponseRejectsProgressBeforePlaybackSnapshotCanClampIt() throws {
        let outOfRange = Data(
            "{\"result\":\"ok\",\"sequence\":7,\"snapshot\":{\"isPaused\":false,\"isPromptActive\":true,\"paceLabel\":\"150w\",\"progress\":1.5,\"scriptTitle\":\"Launch notes\"},\"version\":1}".utf8
        )
        let booleanProgress = Data(
            "{\"result\":\"ok\",\"sequence\":7,\"snapshot\":{\"isPaused\":false,\"isPromptActive\":true,\"paceLabel\":\"150w\",\"progress\":true,\"scriptTitle\":\"Launch notes\"},\"version\":1}".utf8
        )

        for data in [outOfRange, booleanProgress] {
            XCTAssertThrowsError(
                try LocalRemoteProtocol.decodeResponse(data, expectedSequence: 7)
            ) {
                XCTAssertEqual($0 as? LocalRemoteProtocolError, .invalidSnapshot)
            }
        }
    }

    func testFramingRejectsEmptyAndOversizedMessages() throws {
        let message = Data("{}".utf8)
        let framed = try LocalRemoteProtocol.frame(message)

        XCTAssertEqual(framed.count, message.count + 4)
        XCTAssertEqual(
            try LocalRemoteProtocol.messageLength(from: framed.prefix(4)),
            message.count
        )

        XCTAssertThrowsError(try LocalRemoteProtocol.frame(Data())) {
            XCTAssertEqual($0 as? LocalRemoteProtocolError, .emptyMessage)
        }
        XCTAssertThrowsError(
            try LocalRemoteProtocol.frame(Data(repeating: 0, count: 4_097))
        ) {
            XCTAssertEqual($0 as? LocalRemoteProtocolError, .messageTooLarge)
        }

        var excessiveLength = UInt32(4_097).bigEndian
        let excessiveHeader = Data(bytes: &excessiveLength, count: 4)
        XCTAssertThrowsError(try LocalRemoteProtocol.messageLength(from: excessiveHeader)) {
            XCTAssertEqual($0 as? LocalRemoteProtocolError, .messageTooLarge)
        }
    }

    func testNetworkSnapshotBoundsPrivateSurface() throws {
        let oversized = PlaybackSnapshot(
            isPromptActive: true,
            isPaused: true,
            scriptTitle: String(repeating: "A", count: 500),
            paceLabel: String(repeating: "B", count: 100),
            progress: 0.5
        )
        let safe = LocalRemoteProtocol.networkSafeSnapshot(oversized)

        XCTAssertEqual(safe.scriptTitle.count, LocalRemoteProtocol.maximumTitleCharacters)
        XCTAssertEqual(safe.paceLabel.count, LocalRemoteProtocol.maximumPaceLabelCharacters)
        XCTAssertNoThrow(
            try LocalRemoteProtocol.encode(
                LocalRemoteResponse(sequence: 1, result: .ok, snapshot: safe)
            )
        )
    }
}
