import CoreFoundation
import Foundation

enum LocalRemoteResult: String, Codable, Equatable {
    case ok
    case notPresenting
}

struct LocalRemoteRequest: Codable, Equatable {
    let version: Int
    let sequence: UInt64
    let command: RemoteCommand

    init(
        version: Int = LocalRemoteProtocol.version,
        sequence: UInt64,
        command: RemoteCommand
    ) {
        self.version = version
        self.sequence = sequence
        self.command = command
    }
}

struct LocalRemoteResponse: Codable, Equatable {
    let version: Int
    let sequence: UInt64
    let result: LocalRemoteResult
    let snapshot: PlaybackSnapshot

    init(
        version: Int = LocalRemoteProtocol.version,
        sequence: UInt64,
        result: LocalRemoteResult,
        snapshot: PlaybackSnapshot
    ) {
        self.version = version
        self.sequence = sequence
        self.result = result
        self.snapshot = snapshot
    }
}

enum LocalRemoteProtocolError: Error, Equatable, LocalizedError {
    case emptyMessage
    case messageTooLarge
    case malformedMessage
    case unknownField
    case unsupportedVersion
    case invalidSequence
    case replayedSequence
    case invalidSnapshot
    case mismatchedResponse

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "The remote sent an empty message."
        case .messageTooLarge:
            return "The remote message was too large."
        case .malformedMessage, .unknownField, .invalidSnapshot:
            return "The remote sent an invalid message."
        case .unsupportedVersion:
            return "This Kyuva version is not compatible with the remote."
        case .invalidSequence, .replayedSequence, .mismatchedResponse:
            return "The remote session became out of sync."
        }
    }
}

enum LocalRemoteProtocol {
    static let version = 1
    static let maximumMessageBytes = 4_096
    static let maximumTitleCharacters = 160
    static let maximumPaceLabelCharacters = 32

    private static let requestKeys: Set<String> = ["version", "sequence", "command"]
    private static let responseKeys: Set<String> = ["version", "sequence", "result", "snapshot"]
    private static let snapshotKeys: Set<String> = [
        "isPromptActive",
        "isPaused",
        "scriptTitle",
        "paceLabel",
        "progress"
    ]

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func encode(_ request: LocalRemoteRequest) throws -> Data {
        guard request.version == version else {
            throw LocalRemoteProtocolError.unsupportedVersion
        }
        guard request.sequence > 0 else {
            throw LocalRemoteProtocolError.invalidSequence
        }
        return try checkedEncoding(request)
    }

    static func decodeRequest(_ data: Data, after lastSequence: UInt64) throws -> LocalRemoteRequest {
        let object = try strictObject(from: data, expectedKeys: requestKeys)
        guard object["command"] is String else {
            throw LocalRemoteProtocolError.malformedMessage
        }

        let request: LocalRemoteRequest
        do {
            request = try decoder.decode(LocalRemoteRequest.self, from: data)
        } catch {
            throw LocalRemoteProtocolError.malformedMessage
        }

        guard request.version == version else {
            throw LocalRemoteProtocolError.unsupportedVersion
        }
        guard request.sequence > 0 else {
            throw LocalRemoteProtocolError.invalidSequence
        }
        guard request.sequence > lastSequence else {
            throw LocalRemoteProtocolError.replayedSequence
        }
        return request
    }

    static func encode(_ response: LocalRemoteResponse) throws -> Data {
        guard response.version == version else {
            throw LocalRemoteProtocolError.unsupportedVersion
        }
        guard response.sequence > 0 else {
            throw LocalRemoteProtocolError.invalidSequence
        }
        try validate(response.snapshot)
        return try checkedEncoding(response)
    }

    static func decodeResponse(
        _ data: Data,
        expectedSequence: UInt64
    ) throws -> LocalRemoteResponse {
        let object = try strictObject(from: data, expectedKeys: responseKeys)
        guard
            let snapshotObject = object["snapshot"] as? [String: Any],
            Set(snapshotObject.keys) == snapshotKeys
        else {
            throw LocalRemoteProtocolError.unknownField
        }
        try validateRawProgress(snapshotObject["progress"])

        let response: LocalRemoteResponse
        do {
            response = try decoder.decode(LocalRemoteResponse.self, from: data)
        } catch {
            throw LocalRemoteProtocolError.malformedMessage
        }

        guard response.version == version else {
            throw LocalRemoteProtocolError.unsupportedVersion
        }
        guard response.sequence == expectedSequence, expectedSequence > 0 else {
            throw LocalRemoteProtocolError.mismatchedResponse
        }
        try validate(response.snapshot)
        return response
    }

    static func networkSafeSnapshot(_ snapshot: PlaybackSnapshot) -> PlaybackSnapshot {
        PlaybackSnapshot(
            isPromptActive: snapshot.isPromptActive,
            isPaused: snapshot.isPaused,
            scriptTitle: String(snapshot.scriptTitle.prefix(maximumTitleCharacters)),
            paceLabel: String(snapshot.paceLabel.prefix(maximumPaceLabelCharacters)),
            progress: snapshot.progress
        )
    }

    static func frame(_ message: Data) throws -> Data {
        try validateSize(message)
        var length = UInt32(message.count).bigEndian
        var framed = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        framed.append(message)
        return framed
    }

    static func messageLength(from header: Data) throws -> Int {
        guard header.count == MemoryLayout<UInt32>.size else {
            throw LocalRemoteProtocolError.malformedMessage
        }

        let value = header.withUnsafeBytes { rawBuffer in
            rawBuffer.loadUnaligned(as: UInt32.self).bigEndian
        }
        let length = Int(value)
        guard length > 0 else {
            throw LocalRemoteProtocolError.emptyMessage
        }
        guard length <= maximumMessageBytes else {
            throw LocalRemoteProtocolError.messageTooLarge
        }
        return length
    }

    private static func checkedEncoding<T: Encodable>(_ value: T) throws -> Data {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw LocalRemoteProtocolError.malformedMessage
        }
        try validateSize(data)
        return data
    }

    private static func validateSize(_ data: Data) throws {
        guard !data.isEmpty else {
            throw LocalRemoteProtocolError.emptyMessage
        }
        guard data.count <= maximumMessageBytes else {
            throw LocalRemoteProtocolError.messageTooLarge
        }
    }

    private static func strictObject(
        from data: Data,
        expectedKeys: Set<String>
    ) throws -> [String: Any] {
        try validateSize(data)

        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw LocalRemoteProtocolError.malformedMessage
        }
        guard let object = value as? [String: Any] else {
            throw LocalRemoteProtocolError.malformedMessage
        }
        guard Set(object.keys) == expectedKeys else {
            throw LocalRemoteProtocolError.unknownField
        }
        return object
    }

    private static func validate(_ snapshot: PlaybackSnapshot) throws {
        guard
            snapshot.scriptTitle.count <= maximumTitleCharacters,
            snapshot.paceLabel.count <= maximumPaceLabelCharacters,
            snapshot.progress.isFinite,
            (0...1).contains(snapshot.progress)
        else {
            throw LocalRemoteProtocolError.invalidSnapshot
        }
    }

    private static func validateRawProgress(_ value: Any?) throws {
        guard
            let number = value as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID(),
            number.doubleValue.isFinite,
            (0...1).contains(number.doubleValue)
        else {
            throw LocalRemoteProtocolError.invalidSnapshot
        }
    }
}
