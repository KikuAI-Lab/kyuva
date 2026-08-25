import Foundation

enum RemoteCommand: String, CaseIterable {
    case requestSnapshot
    case togglePlayback
    case reset
    case faster
    case slower

    private static let commandKey = "command"

    init?(message: [String: Any]) {
        guard let rawValue = message[Self.commandKey] as? String else { return nil }
        self.init(rawValue: rawValue)
    }

    var message: [String: Any] {
        [Self.commandKey: rawValue]
    }
}

struct PlaybackSnapshot: Equatable {
    let isPromptActive: Bool
    let isPaused: Bool
    let scriptTitle: String
    let paceLabel: String
    let progress: Double

    init(
        isPromptActive: Bool,
        isPaused: Bool,
        scriptTitle: String,
        paceLabel: String,
        progress: Double
    ) {
        self.isPromptActive = isPromptActive
        self.isPaused = isPaused
        self.scriptTitle = scriptTitle
        self.paceLabel = paceLabel
        self.progress = min(1, max(0, progress))
    }

    init?(message: [String: Any]) {
        guard
            let isPromptActive = message["isPromptActive"] as? Bool,
            let isPaused = message["isPaused"] as? Bool,
            let scriptTitle = message["scriptTitle"] as? String,
            let paceLabel = message["paceLabel"] as? String,
            let progress = message["progress"] as? Double
        else {
            return nil
        }

        self.init(
            isPromptActive: isPromptActive,
            isPaused: isPaused,
            scriptTitle: scriptTitle,
            paceLabel: paceLabel,
            progress: progress
        )
    }

    var message: [String: Any] {
        [
            "isPromptActive": isPromptActive,
            "isPaused": isPaused,
            "scriptTitle": scriptTitle,
            "paceLabel": paceLabel,
            "progress": progress
        ]
    }
}
