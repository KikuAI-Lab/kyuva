import Combine
import Foundation
import Network

struct DiscoveredMacRemote: Identifiable {
    let id: String
    let name: String
    fileprivate let endpoint: NWEndpoint
}

final class MacRemoteClient: ObservableObject {
    static let shared = MacRemoteClient()

    enum State: Equatable {
        case idle
        case browsing
        case connecting
        case connected
        case failed(String)

        var statusText: String {
            switch self {
            case .idle:
                return "Remote is off"
            case .browsing:
                return "Choose a nearby Mac"
            case .connecting:
                return "Connecting securely…"
            case .connected:
                return "Connected to Mac"
            case .failed(let message):
                return message
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var hasSecureConnection = false
    @Published private(set) var remotes: [DiscoveredMacRemote] = []
    @Published private(set) var snapshot = PlaybackSnapshot(
        isPromptActive: false,
        isPaused: true,
        scriptTitle: "Kyuva",
        paceLabel: "—",
        progress: 0
    )

    private struct PendingRequest {
        let sequence: UInt64
        let command: RemoteCommand
    }

    private let queue = DispatchQueue(label: "com.kikuai.kyuva.mac-remote-client")
    private var browser: NWBrowser?
    private var browserID = UUID()
    private var browserIsReady = false
    private var connection: NWConnection?
    private var connectionID = UUID()
    private var nextSequence: UInt64 = 0
    private var pendingCommands: [RemoteCommand] = []
    private var inFlight: PendingRequest?
    private var snapshotTimer: DispatchSourceTimer?
    private var isConnectionReady = false

    private init() { }

    func startBrowsing() {
        queue.async { [weak self] in
            self?.startBrowsingOnQueue()
        }
    }

    func connect(to remote: DiscoveredMacRemote, pairingCode: String) {
        let normalizedCode: String
        do {
            normalizedCode = try LocalRemoteSecurity.normalizedPairingCode(pairingCode)
        } catch {
            publish(state: .failed(error.localizedDescription))
            return
        }

        queue.async { [weak self] in
            self?.connectOnQueue(to: remote.endpoint, pairingCode: normalizedCode)
        }
    }

    func send(_ command: RemoteCommand) {
        queue.async { [weak self] in
            self?.enqueue(command)
        }
    }

    func disconnect() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopConnectionOnQueue()
            self.publish(state: .browsing)
            self.startBrowsingOnQueue()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.browserID = UUID()
            self.browser?.stateUpdateHandler = nil
            self.browser?.browseResultsChangedHandler = nil
            self.browser?.cancel()
            self.browser = nil
            self.browserIsReady = false
            self.stopConnectionOnQueue()
            self.publish(remotes: [])
            self.publish(state: .idle)
        }
    }

    private func startBrowsingOnQueue(preservingFailure: Bool = false) {
        guard browser == nil else { return }
        guard connection == nil else { return }

        let parameters = NWParameters.tcp
        let browser = NWBrowser(
            for: .bonjour(type: LocalRemoteSecurity.serviceType, domain: nil),
            using: parameters
        )
        let newBrowserID = UUID()
        browserID = newBrowserID
        browserIsReady = false
        self.browser = browser

        browser.stateUpdateHandler = { [weak self, weak browser] newState in
            guard let self, let browser else { return }
            guard self.browserID == newBrowserID, self.browser === browser else { return }
            switch newState {
            case .ready:
                self.browserIsReady = true
                if !preservingFailure {
                    self.publish(state: .browsing)
                }
            case .failed:
                self.browser = nil
                self.browserIsReady = false
                self.publish(state: .failed("Allow Local Network access, then try again."))
            case .cancelled:
                break
            default:
                break
            }
        }
        browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
            guard let self, let browser else { return }
            guard self.browserID == newBrowserID, self.browser === browser else { return }
            let remotes = results
                .map { result in
                    DiscoveredMacRemote(
                        id: String(describing: result.endpoint),
                        name: Self.displayName(for: result.endpoint),
                        endpoint: result.endpoint
                    )
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            self.publish(remotes: remotes)
        }
        if !preservingFailure {
            publish(state: .browsing)
        }
        browser.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 20) { [weak self, weak browser] in
            guard let self, let browser else { return }
            guard
                self.browserID == newBrowserID,
                self.browser === browser,
                !self.browserIsReady
            else {
                return
            }
            self.browserID = UUID()
            browser.stateUpdateHandler = nil
            browser.browseResultsChangedHandler = nil
            browser.cancel()
            self.browser = nil
            self.publish(remotes: [])
            self.publish(state: .failed("Allow Local Network access, then try again."))
        }
    }

    private func connectOnQueue(to endpoint: NWEndpoint, pairingCode: String) {
        let parameters: NWParameters
        do {
            parameters = try LocalRemoteSecurity.parameters(pairingCode: pairingCode)
        } catch {
            publish(state: .failed(error.localizedDescription))
            return
        }

        stopConnectionOnQueue()
        let connection = NWConnection(to: endpoint, using: parameters)
        let newConnectionID = UUID()
        connectionID = newConnectionID
        self.connection = connection
        nextSequence = 0
        pendingCommands.removeAll()
        inFlight = nil
        publish(state: .connecting)

        connection.stateUpdateHandler = { [weak self, weak connection] newState in
            guard let self, let connection else { return }
            guard self.connectionID == newConnectionID, self.connection === connection else { return }
            switch newState {
            case .ready:
                self.isConnectionReady = true
                self.publish(hasSecureConnection: true)
                self.browserID = UUID()
                self.browser?.stateUpdateHandler = nil
                self.browser?.browseResultsChangedHandler = nil
                self.browser?.cancel()
                self.browser = nil
                self.browserIsReady = false
                self.publish(remotes: [])
                self.publish(state: .connected)
                self.startSnapshotTimer(connectionID: newConnectionID)
                self.enqueue(.requestSnapshot)
            case .failed, .cancelled:
                self.failConnection(
                    "Couldn’t connect. Check the code and Local Network access.",
                    connectionID: newConnectionID
                )
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 8) { [weak self, weak connection] in
            guard let self, let connection else { return }
            guard
                self.connectionID == newConnectionID,
                self.connection === connection,
                !self.isConnectionReady
            else {
                return
            }
            self.failConnection(
                "Couldn’t connect. Check the code and Local Network access.",
                connectionID: newConnectionID
            )
        }
    }

    private func enqueue(_ command: RemoteCommand) {
        guard connection != nil, isConnectionReady else { return }
        if command == .requestSnapshot,
           inFlight?.command == .requestSnapshot || pendingCommands.contains(.requestSnapshot) {
            return
        }
        guard pendingCommands.count < 12 else { return }
        pendingCommands.append(command)
        sendNextIfPossible()
    }

    private func sendNextIfPossible() {
        guard let connection, inFlight == nil, !pendingCommands.isEmpty else { return }
        guard nextSequence < UInt64.max else {
            failConnection("The remote session expired. Pair again.", connectionID: connectionID)
            return
        }

        nextSequence += 1
        let request = PendingRequest(
            sequence: nextSequence,
            command: pendingCommands.removeFirst()
        )
        inFlight = request

        do {
            let message = try LocalRemoteProtocol.encode(
                LocalRemoteRequest(sequence: request.sequence, command: request.command)
            )
            let framed = try LocalRemoteProtocol.frame(message)
            let activeConnectionID = connectionID
            queue.asyncAfter(deadline: .now() + 5) { [weak self, weak connection] in
                guard let self, let connection else { return }
                guard
                    self.connectionID == activeConnectionID,
                    self.connection === connection,
                    self.inFlight?.sequence == request.sequence
                else {
                    return
                }
                self.failConnection(
                    "The Mac stopped responding.",
                    connectionID: activeConnectionID
                )
            }
            connection.send(content: framed, completion: .contentProcessed { [weak self, weak connection] error in
                guard let self, let connection else { return }
                guard self.connectionID == activeConnectionID, self.connection === connection else { return }
                if error != nil {
                    self.failConnection("The Mac became unreachable.", connectionID: activeConnectionID)
                } else {
                    self.receiveHeader(from: connection, connectionID: activeConnectionID)
                }
            })
        } catch {
            failConnection(error.localizedDescription, connectionID: connectionID)
        }
    }

    private func receiveHeader(from connection: NWConnection, connectionID: UUID) {
        connection.receive(
            minimumIncompleteLength: MemoryLayout<UInt32>.size,
            maximumLength: MemoryLayout<UInt32>.size
        ) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            guard self.connectionID == connectionID, self.connection === connection else { return }
            guard error == nil, !isComplete, let data else {
                self.failConnection("The Mac became unreachable.", connectionID: connectionID)
                return
            }

            do {
                let length = try LocalRemoteProtocol.messageLength(from: data)
                self.receiveMessage(length: length, from: connection, connectionID: connectionID)
            } catch {
                self.failConnection(error.localizedDescription, connectionID: connectionID)
            }
        }
    }

    private func receiveMessage(
        length: Int,
        from connection: NWConnection,
        connectionID: UUID
    ) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) {
            [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            guard self.connectionID == connectionID, self.connection === connection else { return }
            guard
                error == nil,
                !isComplete,
                let data,
                data.count == length,
                let request = self.inFlight
            else {
                self.failConnection("The Mac became unreachable.", connectionID: connectionID)
                return
            }

            do {
                let response = try LocalRemoteProtocol.decodeResponse(
                    data,
                    expectedSequence: request.sequence
                )
                self.inFlight = nil
                self.publish(snapshot: response.snapshot)
                self.publish(
                    state: response.result == .ok
                        ? .connected
                        : .failed("Show the teleprompter on your Mac first.")
                )
                self.sendNextIfPossible()
            } catch {
                self.failConnection(error.localizedDescription, connectionID: connectionID)
            }
        }
    }

    private func startSnapshotTimer(connectionID: UUID) {
        snapshotTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self, self.connectionID == connectionID else { return }
            self.enqueue(.requestSnapshot)
        }
        snapshotTimer = timer
        timer.resume()
    }

    private func stopConnectionOnQueue() {
        connectionID = UUID()
        snapshotTimer?.setEventHandler { }
        snapshotTimer?.cancel()
        snapshotTimer = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        isConnectionReady = false
        publish(hasSecureConnection: false)
        pendingCommands.removeAll()
        inFlight = nil
        nextSequence = 0
    }

    private func failConnection(_ message: String, connectionID: UUID) {
        guard self.connectionID == connectionID else { return }
        stopConnectionOnQueue()
        publish(state: .failed(message))
        startBrowsingOnQueue(preservingFailure: true)
    }

    private static func displayName(for endpoint: NWEndpoint) -> String {
        if case .service(let name, _, _, _) = endpoint {
            return name
        }
        return "Kyuva Mac"
    }

    private func publish(state: State) {
        DispatchQueue.main.async { [weak self] in
            self?.state = state
        }
    }

    private func publish(remotes: [DiscoveredMacRemote]) {
        DispatchQueue.main.async { [weak self] in
            self?.remotes = remotes
        }
    }

    private func publish(snapshot: PlaybackSnapshot) {
        DispatchQueue.main.async { [weak self] in
            self?.snapshot = snapshot
        }
    }

    private func publish(hasSecureConnection: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.hasSecureConnection = hasSecureConnection
        }
    }
}
