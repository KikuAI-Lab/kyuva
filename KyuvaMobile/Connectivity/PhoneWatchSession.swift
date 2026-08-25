import Foundation
import WatchConnectivity

final class PhoneWatchSession: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchSession()

    private weak var scrollController: ScrollController?
    private var scriptTitle = "Kyuva"

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func bind(scrollController: ScrollController, scriptTitle: String) {
        self.scrollController = scrollController
        self.scriptTitle = scriptTitle
        publishSnapshot()
    }

    func unbind(scrollController: ScrollController) {
        guard self.scrollController === scrollController else { return }
        self.scrollController = nil
        publishSnapshot()
    }

    func publishSnapshot() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        try? session.updateApplicationContext(snapshot.message)
    }

    private var snapshot: PlaybackSnapshot {
        guard let scrollController else {
            return PlaybackSnapshot(
                isPromptActive: false,
                isPaused: true,
                scriptTitle: scriptTitle,
                paceLabel: "—",
                progress: 0
            )
        }

        return PlaybackSnapshot(
            isPromptActive: true,
            isPaused: scrollController.isPaused,
            scriptTitle: scriptTitle,
            paceLabel: scrollController.paceControlLabel,
            progress: scrollController.progress
        )
    }

    private func apply(_ command: RemoteCommand) -> PlaybackSnapshot {
        guard let scrollController else { return snapshot }

        switch command {
        case .requestSnapshot:
            break
        case .togglePlayback:
            scrollController.togglePause()
        case .reset:
            scrollController.reset()
        case .faster:
            scrollController.adjustPace(steps: 1)
        case .slower:
            scrollController.adjustPace(steps: -1)
        }

        publishSnapshot()
        return snapshot
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard error == nil, activationState == .activated else { return }
        DispatchQueue.main.async { [weak self] in
            self?.publishSnapshot()
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let command = RemoteCommand(message: message) else {
            replyHandler(snapshot.message)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            replyHandler(self.apply(command).message)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) { }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.publishSnapshot()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        DispatchQueue.main.async { [weak self] in
            self?.publishSnapshot()
        }
    }
}
