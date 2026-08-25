import SwiftUI

struct WatchRemoteView: View {
    @EnvironmentObject private var session: WatchSessionController

    private var controlsEnabled: Bool {
        session.isReachable && session.snapshot.isPromptActive
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(session.snapshot.scriptTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(session.statusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                ProgressView(value: session.snapshot.progress)
                    .tint(.cyan)
                    .accessibilityLabel("Prompt progress")
                    .accessibilityValue("\(Int(session.snapshot.progress * 100)) percent")

                Button {
                    session.send(.togglePlayback)
                } label: {
                    Image(systemName: session.snapshot.isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(!controlsEnabled)
                .accessibilityLabel(session.snapshot.isPaused ? "Play" : "Pause")

                HStack(spacing: 8) {
                    Button {
                        session.send(.slower)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .accessibilityLabel("Slower")

                    Text(session.snapshot.paceLabel)
                        .font(.caption.monospacedDigit().bold())
                        .frame(minWidth: 36)
                        .accessibilityLabel("Current pace")

                    Button {
                        session.send(.faster)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Faster")
                }
                .disabled(!controlsEnabled)

                Button {
                    session.send(.reset)
                } label: {
                    Label("Start over", systemImage: "backward.end.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!controlsEnabled)
            }
            .padding(.horizontal, 4)
        }
    }
}
