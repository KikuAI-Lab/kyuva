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
    @State private var isShowingSettings = false
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

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
        .onChange(of: scrollController.isPaused) {
            PhoneWatchSession.shared.publishSnapshot()
        }
        .onChange(of: scrollController.paceControlLabel) {
            PhoneWatchSession.shared.publishSnapshot()
        }
        .onChange(of: Int(scrollController.progress * 100)) {
            PhoneWatchSession.shared.publishSnapshot()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            scrollController.reset()
            scrollController.applyPersistedScrollSpeed()
            PhoneWatchSession.shared.bind(
                scrollController: scrollController,
                scriptTitle: script.name
            )
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            scrollController.pause()
            PhoneWatchSession.shared.unbind(scrollController: scrollController)
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
            scrollController.togglePause()
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
                        scrollController.reset()
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
                    .accessibilityLabel(scrollController.isPaused ? "Play" : "Pause")

                    Button {
                        scrollController.adjustPace(steps: 1)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
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
}
