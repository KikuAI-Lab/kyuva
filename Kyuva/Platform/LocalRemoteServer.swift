import Combine
import Foundation
import Network

struct LocalRemoteCommandResult {
    let result: LocalRemoteResult
    let snapshot: PlaybackSnapshot
}

final class LocalRemoteServer: ObservableObject {
    static let shared = LocalRemoteServer()

    enum State: Equatable {
        case idle
        case starting
        case ready
        case connected
        case failed(String)

        var statusText: String {
            switch self {
            case .idle:
                return "Remote is off"
            case .starting:
                return "Starting local remote…"
            case .ready:
                return "Waiting for iPhone"
            case .connected:
                return "iPhone connected"
            case .failed(let message):
                return message
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var pairingCode: String?

    var commandHandler: ((RemoteCommand) -> LocalRemoteCommandResult)?

    // The remote carries only tiny control messages. Keeping connection state on
    // the main queue avoids cross-queue races with AppKit and the command handler.
    private let queue = DispatchQueue.main
    private var listener: NWListener?
    private var authorizationBrowser: NWBrowser?
    private var connection: NWConnection?
    private var sessionID = UUID()
    private var lastSequence: UInt64 = 0
    private var authenticatedConnection = false

    private init() { }

    func start() {
        let code: String
        let parameters: NWParameters
        do {
            code = try LocalRemoteSecurity.generatePairingCode()
            parameters = try LocalRemoteSecurity.parameters(pairingCode: code)
        } catch {
            state = .failed(error.localizedDescription)
            pairingCode = nil
            return
        }

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: .any)
        } catch {
            state = .failed("Kyuva could not start the local remote.")
            pairingCode = nil
            return
        }

        stopNetworking()
        let newSessionID = UUID()
        sessionID = newSessionID
        pairingCode = code
        state = .starting
        lastSequence = 0
        authenticatedConnection = false
        self.listener = listener

        listener.service = NWListener.Service(
            name: "Kyuva Remote",
            type: LocalRemoteSecurity.serviceType
        )
        listener.stateUpdateHandler = { [weak self, weak listener] newState in
            guard let self, let listener else { return }
            self.handleListenerState(newState, listener: listener, sessionID: newSessionID)
        }
        listener.serviceRegistrationUpdateHandler = { [weak self, weak listener] change in
            guard let self, let listener else { return }
            guard self.sessionID == newSessionID, self.listener === listener else { return }
#if DEBUG
            NSLog("Kyuva local remote registration state: %@", String(describing: change))
#endif
            if case .add = change {
                self.publishState(.ready, sessionID: newSessionID)
            }
        }
        listener.newConnectionHandler = { [weak self] newConnection in
            self?.accept(newConnection, sessionID: newSessionID)
        }
        listener.start(queue: queue)
        startAuthorizationBrowser(sessionID: newSessionID)
        queue.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self else { return }
            guard self.sessionID == newSessionID, self.state == .starting else { return }
            self.failSession(
                "Allow Local Network for Kyuva in System Settings, then start again.",
                sessionID: newSessionID
            )
        }
    }

    func stop() {
        sessionID = UUID()
        stopNetworking()
        pairingCode = nil
        state = .idle
    }

    private func stopNetworking() {
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        listener?.stateUpdateHandler = nil
        listener?.serviceRegistrationUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil
        authorizationBrowser?.stateUpdateHandler = nil
        authorizationBrowser?.browseResultsChangedHandler = nil
        authorizationBrowser?.cancel()
        authorizationBrowser = nil
        authenticatedConnection = false
        lastSequence = 0
    }

    private func startAuthorizationBrowser(sessionID: UUID) {
        let browserParameters = NWParameters.tcp
        let browser = NWBrowser(
            for: .bonjour(type: LocalRemoteSecurity.serviceType, domain: nil),
            using: browserParameters
        )
        authorizationBrowser = browser
        browser.browseResultsChangedHandler = { _, _ in }
        browser.stateUpdateHandler = { [weak self, weak browser] newState in
            guard let self, let browser else { return }
            guard self.sessionID == sessionID, self.authorizationBrowser === browser else {
                return
            }
#if DEBUG
            NSLog("Kyuva local remote authorization state: %@", String(describing: newState))
#endif
            if case .failed = newState {
                self.failSession(
                    "Kyuva could not access the local network.",
                    sessionID: sessionID
                )
            }
        }
        browser.start(queue: queue)
    }

    private func handleListenerState(
        _ newState: NWListener.State,
        listener: NWListener,
        sessionID: UUID
    ) {
        guard self.sessionID == sessionID, self.listener === listener else { return }

        switch newState {
        case .ready:
            break
        case .failed:
            failSession("Kyuva could not advertise the local remote.", sessionID: sessionID)
        case .cancelled:
            break
        default:
            break
        }
    }

    private func accept(_ newConnection: NWConnection, sessionID: UUID) {
        guard self.sessionID == sessionID else {
            newConnection.cancel()
            return
        }
        guard connection == nil else {
            newConnection.cancel()
            return
        }

        connection = newConnection
        authenticatedConnection = false
        newConnection.stateUpdateHandler = { [weak self, weak newConnection] newState in
            guard let self, let newConnection else { return }
            self.handleConnectionState(
                newState,
                connection: newConnection,
                sessionID: sessionID
            )
        }
        newConnection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 10) { [weak self, weak newConnection] in
            guard let self, let newConnection else { return }
            guard
                self.sessionID == sessionID,
                self.connection === newConnection,
                !self.authenticatedConnection
            else {
                return
            }
            newConnection.cancel()
        }
    }

    private func handleConnectionState(
        _ newState: NWConnection.State,
        connection: NWConnection,
        sessionID: UUID
    ) {
        guard self.sessionID == sessionID, self.connection === connection else { return }

        switch newState {
        case .ready:
            authenticatedConnection = true
            authorizationBrowser?.stateUpdateHandler = nil
            authorizationBrowser?.browseResultsChangedHandler = nil
            authorizationBrowser?.cancel()
            authorizationBrowser = nil
            listener?.stateUpdateHandler = nil
            listener?.serviceRegistrationUpdateHandler = nil
            listener?.newConnectionHandler = nil
            listener?.cancel()
            listener = nil
            publishConnected(sessionID: sessionID)
            receiveHeader(from: connection, sessionID: sessionID)
        case .failed, .cancelled:
            connection.stateUpdateHandler = nil
            self.connection = nil
            if authenticatedConnection {
                endAuthenticatedSession(sessionID: sessionID)
            } else {
                publishState(.ready, sessionID: sessionID)
            }
        default:
            break
        }
    }

    private func receiveHeader(from connection: NWConnection, sessionID: UUID) {
        connection.receive(
            minimumIncompleteLength: MemoryLayout<UInt32>.size,
            maximumLength: MemoryLayout<UInt32>.size
        ) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            guard self.sessionID == sessionID, self.connection === connection else { return }
            guard error == nil, !isComplete, let data else {
                self.endAuthenticatedSession(sessionID: sessionID)
                return
            }

            do {
                let length = try LocalRemoteProtocol.messageLength(from: data)
                self.receiveMessage(length: length, from: connection, sessionID: sessionID)
            } catch {
                self.endAuthenticatedSession(sessionID: sessionID)
            }
        }
    }

    private func receiveMessage(
        length: Int,
        from connection: NWConnection,
        sessionID: UUID
    ) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) {
            [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            guard self.sessionID == sessionID, self.connection === connection else { return }
            guard error == nil, !isComplete, let data, data.count == length else {
                self.endAuthenticatedSession(sessionID: sessionID)
                return
            }

            let request: LocalRemoteRequest
            do {
                request = try LocalRemoteProtocol.decodeRequest(data, after: self.lastSequence)
                self.lastSequence = request.sequence
            } catch {
                self.endAuthenticatedSession(sessionID: sessionID)
                return
            }

            DispatchQueue.main.async { [weak self, weak connection] in
                guard let self, let connection else { return }
                guard self.sessionID == sessionID, self.connection === connection else { return }

                let result = self.commandHandler?(request.command) ?? LocalRemoteCommandResult(
                    result: .notPresenting,
                    snapshot: PlaybackSnapshot(
                        isPromptActive: false,
                        isPaused: true,
                        scriptTitle: "Kyuva",
                        paceLabel: "—",
                        progress: 0
                    )
                )
                let response = LocalRemoteResponse(
                    sequence: request.sequence,
                    result: result.result,
                    snapshot: LocalRemoteProtocol.networkSafeSnapshot(result.snapshot)
                )

                self.queue.async { [weak self, weak connection] in
                    guard let self, let connection else { return }
                    self.send(response, on: connection, sessionID: sessionID)
                }
            }
        }
    }

    private func send(
        _ response: LocalRemoteResponse,
        on connection: NWConnection,
        sessionID: UUID
    ) {
        guard self.sessionID == sessionID, self.connection === connection else { return }

        do {
            let message = try LocalRemoteProtocol.encode(response)
            let framed = try LocalRemoteProtocol.frame(message)
            connection.send(content: framed, completion: .contentProcessed { [weak self, weak connection] error in
                guard let self, let connection else { return }
                guard self.sessionID == sessionID, self.connection === connection else { return }
                if error != nil {
                    self.endAuthenticatedSession(sessionID: sessionID)
                } else {
                    self.receiveHeader(from: connection, sessionID: sessionID)
                }
            })
        } catch {
            endAuthenticatedSession(sessionID: sessionID)
        }
    }

    private func endAuthenticatedSession(sessionID: UUID) {
        guard self.sessionID == sessionID else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.sessionID == sessionID else { return }
            self.stop()
        }
    }

    private func failSession(_ message: String, sessionID: UUID) {
        guard self.sessionID == sessionID else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.sessionID == sessionID else { return }
            self.stopNetworking()
            self.pairingCode = nil
            self.state = .failed(message)
        }
    }

    private func publishState(_ state: State, sessionID: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.sessionID == sessionID else { return }
            if state == .ready {
                self.authorizationBrowser?.stateUpdateHandler = nil
                self.authorizationBrowser?.browseResultsChangedHandler = nil
                self.authorizationBrowser?.cancel()
                self.authorizationBrowser = nil
            }
            self.state = state
        }
    }

    private func publishConnected(sessionID: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.sessionID == sessionID else { return }
            self.pairingCode = nil
            self.state = .connected
        }
    }
}
