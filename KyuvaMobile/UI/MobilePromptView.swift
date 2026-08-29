import SwiftUI
import UIKit

private struct PromptContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MobilePromptView: View {
    let script: Script

    @Environment(\.dismiss) private var dismiss
    @StateObject private var scrollController = ScrollController()
    @StateObject private var speechRecognizer = OnDeviceSpeechRecognizer()
    @ObservedObject private var proStore = ProEntitlementStore.shared
    @State private var isShowingSettings = false
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var voiceMatcher: VoicePositionMatcher?
    @State private var hasRecordedCurrentCompletion = false

    @AppStorage("fontSize") private var fontSize = 34.0
    @AppStorage("mirrorText") private var mirrorText = false
    @AppStorage("stageDirectionStyle") private var stageDirectionStyle = 1

    private var displayedLines: [PromptLine] {
        if stageDirectionStyle == 2 {
            return script.promptLines.filter { !$0.isStageDirection }
        }
        return script.promptLines
    }

    private var pacedWordCount: Int {
        script.wordCount(excludingStageDirections: stageDirectionStyle != 0)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black
                    .ignoresSafeArea()

                promptContent(in: geometry.size)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .top
                    )
                    .clipped()

                readingCue

                chrome
            }
            .onAppear {
                viewportHeight = geometry.size.height
                updateContentMetrics()
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                viewportHeight = newHeight
                updateContentMetrics()
            }
        }
        .foregroundStyle(.white)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                MobilePromptSettingsView()
            }
            .presentationDetents([.medium, .large])
        }
        .onPreferenceChange(PromptContentHeightKey.self) { newHeight in
            contentHeight = newHeight
            updateContentMetrics()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            scrollController.applyPersistedScrollSpeed()
            updateContentMetrics()
        }
        .onChange(of: scrollController.isPaused) { _, isPaused in
            if speechRecognizer.state.isEngaged && !isPaused {
                scrollController.pause()
            }
            PhoneWatchSession.shared.publishSnapshot()
        }
        .onChange(of: scrollController.paceControlLabel) {
            PhoneWatchSession.shared.publishSnapshot()
        }
        .onChange(of: Int(scrollController.progress * 100)) { _, progressPercent in
            PhoneWatchSession.shared.publishSnapshot()
            recordCompletedPromptIfNeeded(progressPercent: progressPercent)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            hasRecordedCurrentCompletion = false
            scrollController.reset()
            scrollController.applyPersistedScrollSpeed()
            PhoneWatchSession.shared.bind(
                scrollController: scrollController,
                scriptTitle: script.name,
                commandHandler: handleWatchCommand
            )
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            speechRecognizer.stop()
            voiceMatcher = nil
            scrollController.pause()
            PhoneWatchSession.shared.unbind(scrollController: scrollController)
        }
        .onChange(of: speechRecognizer.latestTranscript) { _, transcript in
            consumeVoiceTranscript(transcript)
        }
        .task {
            await proStore.prepare()
        }
    }

    private func promptContent(in size: CGSize) -> some View {
        VStack(spacing: max(12, fontSize * 0.35)) {
            Color.clear
                .frame(height: max(0, size.height / 2 - fontSize))

            ForEach(displayedLines) { line in
                Text(line.text)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        .white.opacity(
                            line.isStageDirection && stageDirectionStyle == 1 ? 0.5 : 1
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(line.text)
            }

            Color.clear
                .frame(height: max(0, size.height / 2 - fontSize))
        }
        .padding(.horizontal, max(24, size.width * 0.08))
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { contentGeometry in
                Color.clear.preference(
                    key: PromptContentHeightKey.self,
                    value: contentGeometry.size.height
                )
            }
        }
        .offset(y: -scrollController.scrollOffset)
        .scaleEffect(x: mirrorText ? -1 : 1, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            handlePromptTap()
        }
    }

    private var readingCue: some View {
        GeometryReader { geometry in
            HStack(spacing: 10) {
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan)

                Rectangle()
                    .fill(.cyan.opacity(0.65))
                    .frame(height: 2)
            }
            .padding(.horizontal, 12)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Close prompt")

                VStack(alignment: .leading, spacing: 2) {
                    Text(script.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(progressLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Button {
                    toggleVoiceFollow()
                } label: {
                    Image(
                        systemName: speechRecognizer.state.isListening
                            ? "waveform.circle.fill"
                            : "waveform.circle"
                    )
                    .foregroundStyle(speechRecognizer.state.isListening ? .cyan : .white)
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(speechRecognizer.state == .requestingPermission)
                .accessibilityLabel(
                    speechRecognizer.state.isListening
                        ? "Stop Voice Follow"
                        : "Start Voice Follow"
                )
                .accessibilityValue(voiceStatusLabel)

                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Prompt settings")
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .background(.black.opacity(0.9))

            Spacer()

            VStack(spacing: 10) {
                ProgressView(value: scrollController.progress)
                    .tint(.cyan)
                    .accessibilityLabel("Prompt progress")
                    .accessibilityValue("\(Int(scrollController.progress * 100)) percent")

                HStack(spacing: 10) {
                    Button {
                        resetPromptPosition()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start over")

                    Button {
                        scrollController.adjustPace(steps: -1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(speechRecognizer.state.isEngaged)
                    .accessibilityLabel("Slower")

                    Button {
                        scrollController.togglePause()
                    } label: {
                        Image(systemName: scrollController.isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .foregroundStyle(.black)
                            .frame(width: 64, height: 52)
                            .background(.cyan, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(speechRecognizer.state.isEngaged)
                    .accessibilityLabel(scrollController.isPaused ? "Play" : "Pause")

                    Button {
                        scrollController.adjustPace(steps: 1)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(speechRecognizer.state.isEngaged)
                    .accessibilityLabel("Faster")

                    Text(scrollController.paceControlLabel)
                        .font(.callout.monospacedDigit().bold())
                        .lineLimit(1)
                        .frame(minWidth: 40)
                        .layoutPriority(1)
                        .accessibilityLabel("Current pace")
                        .accessibilityValue(scrollController.paceControlLabel)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.black)
        }
    }

    private var progressLabel: String {
        switch speechRecognizer.state {
        case .requestingPermission:
            return "Preparing Voice Follow…"
        case .listening:
            return "Voice Follow · \(Int(scrollController.progress * 100))%"
        case .permissionDenied:
            return "Voice Follow needs microphone and Speech access"
        case .unsupported(let localeIdentifier):
            return "On-device speech unavailable for \(localeIdentifier)"
        case .failed:
            return "Voice Follow stopped · tap to retry"
        case .idle:
            break
        }

        guard let remaining = scrollController.remainingTime else {
            return "Paused at the start"
        }
        let seconds = max(0, Int(remaining.rounded()))
        return "\(Int(scrollController.progress * 100))% · \(seconds / 60):\(String(format: "%02d", seconds % 60)) left"
    }

    private func updateContentMetrics() {
        guard viewportHeight > 0, contentHeight > 0 else { return }
        scrollController.updateContentMetrics(
            contentHeight: contentHeight,
            visibleHeight: viewportHeight,
            wordCount: pacedWordCount
        )
    }

    private var voiceStatusLabel: String {
        switch speechRecognizer.state {
        case .idle:
            return proStore.accessState.hasAccess ? "Off" : "Requires Kyuva Pro"
        case .requestingPermission:
            return "Requesting permission"
        case .listening(let localeIdentifier):
            return "Listening on device in \(localeIdentifier)"
        case .permissionDenied:
            return "Permission denied"
        case .unsupported(let localeIdentifier):
            return "On-device recognition unavailable for \(localeIdentifier)"
        case .failed:
            return "Stopped after a recognition error"
        }
    }

    private func toggleVoiceFollow() {
        if speechRecognizer.state.isEngaged {
            speechRecognizer.stop()
            voiceMatcher = nil
            return
        }

        guard proStore.accessState.hasAccess else {
            isShowingSettings = true
            return
        }

        scrollController.manualPause()
        voiceMatcher = VoicePositionMatcher(
            tokens: script.tokens,
            startTokenIndex: voiceStartTokenIndex
        )

        Task {
            await speechRecognizer.start(scriptText: script.content)
        }
    }

    private func handlePromptTap() {
        if speechRecognizer.state.isEngaged {
            speechRecognizer.stop()
            voiceMatcher = nil
        } else {
            scrollController.togglePause()
        }
    }

    private func consumeVoiceTranscript(_ transcript: String) {
        guard var matcher = voiceMatcher else { return }
        defer { voiceMatcher = matcher }

        guard let match = matcher.consume(transcript) else { return }
        scrollController.pause()
        scrollController.goToOffset(
            CGFloat(match.progress) * scrollController.maximumOffset
        )
        PhoneWatchSession.shared.publishSnapshot()
    }

    private var voiceStartTokenIndex: Int {
        guard !script.tokens.isEmpty, scrollController.progress > 0 else { return -1 }
        return min(
            script.tokens.count - 1,
            Int((scrollController.progress * Double(script.tokens.count - 1)).rounded(.down))
        )
    }

    private func handleWatchCommand(_ command: RemoteCommand) -> Bool {
        guard speechRecognizer.state.isEngaged else { return false }

        switch command {
        case .requestSnapshot:
            return false
        case .togglePlayback:
            speechRecognizer.stop()
            voiceMatcher = nil
        case .reset:
            resetPromptPosition()
        case .faster, .slower:
            break
        }

        return true
    }

    private func resetPromptPosition() {
        scrollController.reset()
        hasRecordedCurrentCompletion = false
        if var matcher = voiceMatcher {
            matcher.reset()
            voiceMatcher = matcher
        }
    }

    private func recordCompletedPromptIfNeeded(progressPercent: Int) {
        guard progressPercent >= 98, !hasRecordedCurrentCompletion else { return }
        hasRecordedCurrentCompletion = true
        ReviewPromptPolicy().recordSuccessfulPrompt()
    }
}
