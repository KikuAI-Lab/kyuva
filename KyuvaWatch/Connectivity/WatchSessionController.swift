import Combine
import Foundation
import WatchConnectivity

final class WatchSessionController: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var isReachable = false
    @Published private(set) var statusText = "Connecting…"
    @Published private(set) var snapshot = PlaybackSnapshot(
        isPromptActive: false,
        isPaused: true,
        scriptTitle: "Kyuva",
        paceLabel: "—",
        progress: 0
    )

    override init() {
        super.init()
        guard WCSession.isSupported() else {
            statusText = "Watch Connectivity unavailable"
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ command: RemoteCommand) {
        let session = WCSession.default
        guard session.isReachable else {
            statusText = "Open Kyuva on iPhone"
            isReachable = false
            return
        }

        statusText = "Sending…"
        session.sendMessage(
            command.message,
            replyHandler: { [weak self] message in
                guard let snapshot = PlaybackSnapshot(message: message) else {
                    DispatchQueue.main.async {
                        self?.statusText = "Invalid response"
                    }
                    return
                }
                DispatchQueue.main.async {
                    self?.snapshot = snapshot
                    self?.statusText = snapshot.isPromptActive ? "Connected" : "Open the prompt on iPhone"
                }
            },
            errorHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isReachable = false
                    self?.statusText = "iPhone not reachable"
                }
            }
        )
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isReachable = error == nil && session.isReachable
            if error != nil {
                self.statusText = "iPhone not reachable"
                return
            }
            if let contextSnapshot = PlaybackSnapshot(message: session.receivedApplicationContext) {
                self.snapshot = contextSnapshot
            }
            self.statusText = self.snapshot.isPromptActive ? "Connected" : "Open the prompt on iPhone"
            if self.isReachable {
                self.send(.requestSnapshot)
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isReachable = session.isReachable
            if session.isReachable {
                self.send(.requestSnapshot)
            } else {
                self.statusText = "Open Kyuva on iPhone"
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let snapshot = PlaybackSnapshot(message: applicationContext) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.snapshot = snapshot
            self?.statusText = snapshot.isPromptActive ? "Connected" : "Open the prompt on iPhone"
        }
    }
}
