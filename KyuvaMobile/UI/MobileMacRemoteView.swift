import SwiftUI

struct MobileMacRemoteView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var client = MacRemoteClient.shared
    @State private var selectedRemoteID: String?
    @State private var pairingCode = ""

    private var selectedRemote: DiscoveredMacRemote? {
        client.remotes.first { $0.id == selectedRemoteID }
    }

    var body: some View {
        Form {
            Section {
                Label(client.state.statusText, systemImage: statusSymbol)
                    .foregroundStyle(statusColor)
                    .accessibilityIdentifier("iphoneMacRemoteStatus")
            }

            if client.hasSecureConnection {
                promptSection
                controlsSection
                Section {
                    Button("Disconnect", role: .destructive) {
                        client.disconnect()
                        selectedRemoteID = nil
                        pairingCode = ""
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                discoverySection
                pairingSection
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Works on your local network", systemImage: "wifi")
                    Label("Protected by a one-time encrypted session", systemImage: "lock.fill")
                    Label("Script text never travels through this remote", systemImage: "doc.badge.ellipsis")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Mac Remote")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            if client.hasSecureConnection {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        client.send(.requestSnapshot)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh Mac prompt")
                }
            }
        }
        .onAppear {
            client.startBrowsing()
        }
        .onDisappear {
            client.stop()
        }
        .onChange(of: client.remotes.map(\.id)) { _, remoteIDs in
            if selectedRemoteID == nil {
                selectedRemoteID = remoteIDs.first
            } else if !remoteIDs.contains(selectedRemoteID ?? "") {
                selectedRemoteID = remoteIDs.first
            }
        }
    }

    private var discoverySection: some View {
        Section("Nearby Macs") {
            if client.remotes.isEmpty {
                HStack {
                    ProgressView()
                    Text("Start Local Remote in Kyuva Settings on your Mac.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(client.remotes) { remote in
                    Button {
                        selectedRemoteID = remote.id
                    } label: {
                        HStack {
                            Label(remote.name, systemImage: "laptopcomputer")
                            Spacer()
                            if selectedRemoteID == remote.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(selectedRemoteID == remote.id ? "Selected" : "Not selected")
                }
            }
        }
    }

    private var pairingSection: some View {
        Section("One-time code") {
            TextField("XXXX-XXXX-XXXX-XXXX", text: $pairingCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .accessibilityLabel("Mac pairing code")
                .accessibilityIdentifier("iphoneMacRemotePairingCode")

            Button("Connect Securely") {
                guard let selectedRemote else { return }
                client.connect(to: selectedRemote, pairingCode: pairingCode)
            }
            .frame(maxWidth: .infinity)
            .disabled(selectedRemote == nil || pairingCode.isEmpty || client.state == .connecting)
            .accessibilityIdentifier("iphoneMacRemoteConnect")
        }
    }

    private var promptSection: some View {
        Section("Mac Prompt") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(client.snapshot.scriptTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    Text(client.snapshot.paceLabel)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: client.snapshot.progress)
                    .accessibilityLabel("Mac prompt progress")
                    .accessibilityValue("\(Int(client.snapshot.progress * 100)) percent")
                Text(client.snapshot.isPromptActive ? "Ready" : "Show the teleprompter on your Mac")
                    .font(.caption)
                    .foregroundStyle(client.snapshot.isPromptActive ? Color.secondary : Color.orange)
            }
        }
    }

    private var controlsSection: some View {
        Section("Controls") {
            HStack(spacing: 12) {
                remoteButton("Slower", systemImage: "minus", command: .slower)
                remoteButton(
                    client.snapshot.isPaused ? "Play" : "Pause",
                    systemImage: client.snapshot.isPaused ? "play.fill" : "pause.fill",
                    command: .togglePlayback,
                    prominent: true
                )
                remoteButton("Faster", systemImage: "plus", command: .faster)
            }

            Button {
                client.send(.reset)
            } label: {
                Label("Reset to Start", systemImage: "backward.end.fill")
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.bordered)
            .disabled(!client.snapshot.isPromptActive)
            .accessibilityIdentifier("iphoneMacRemoteReset")
        }
    }

    private func remoteButton(
        _ title: String,
        systemImage: String,
        command: RemoteCommand,
        prominent: Bool = false
    ) -> some View {
        Button {
            client.send(command)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(prominent ? Color.accentColor : Color.secondary)
        .disabled(!client.snapshot.isPromptActive)
        .accessibilityIdentifier("iphoneMacRemote\(title)")
    }

    private var statusSymbol: String {
        if client.hasSecureConnection {
            return client.snapshot.isPromptActive ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
        }
        if case .failed = client.state {
            return "exclamationmark.triangle.fill"
        }
        return "laptopcomputer.and.iphone"
    }

    private var statusColor: Color {
        if client.hasSecureConnection, client.snapshot.isPromptActive {
            return .green
        }
        if case .failed = client.state {
            return .orange
        }
        return .secondary
    }
}
