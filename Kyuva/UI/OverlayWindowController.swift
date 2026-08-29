import AppKit
import SwiftUI
import Combine

struct WindowDragTracker {
    private var startOrigin: CGPoint?

    mutating func origin(currentOrigin: CGPoint, translation: CGPoint) -> CGPoint {
        let origin = startOrigin ?? currentOrigin
        startOrigin = origin
        return CGPoint(
            x: origin.x + translation.x,
            y: origin.y - translation.y
        )
    }

    mutating func reset() {
        startOrigin = nil
    }
}

/// Controller for the camera-side overlay window.
///
/// The overlay is a normal macOS window. It may be visible in screen shares
/// and recordings, so users should verify the preview or share a single app
/// window that omits Kyuva.
class OverlayWindowController: NSWindowController {
    
    private var scrollController: ScrollController?
    private var scriptManager: ScriptManager?
    private var hotkeyManager: HotkeyManager?
    private var isHovering = false
    private var cancellables = Set<AnyCancellable>()
    private var dragTracker = WindowDragTracker()
    
    convenience init() {
        // Get screen with notch (main screen on MacBooks with notch)
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        _ = screen.visibleFrame
        
        // Get overlay size from settings (defaults: 350x150)
        let width = CGFloat(UserDefaults.standard.double(forKey: "overlayWidth") > 0 
                           ? UserDefaults.standard.double(forKey: "overlayWidth") : 350)
        let height = CGFloat(UserDefaults.standard.double(forKey: "overlayHeight") > 0 
                            ? UserDefaults.standard.double(forKey: "overlayHeight") : 150)
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height // Flush with top menu bar
        
        let window = OverlayWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .resizable], // Native resize support
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        
        setupWindow(window)
        setupContent()
        setupManagers()
    }
    
    private func setupWindow(_ window: NSWindow) {
        // Always on top
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Transparent, borderless
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        
        // Allow mouse events for hover-to-pause
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        
        // Don't show in dock or app switcher
        window.isExcludedFromWindowsMenu = true
        
        // Set min/max size for resize
        window.minSize = NSSize(width: 200, height: 80)
        window.maxSize = NSSize(width: 600, height: 400)
        
        // Listen for resize to save size
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: window
        )
    }
    
    @objc private func windowDidResize(_ notification: Notification) {
        guard let window = window else { return }
        UserDefaults.standard.set(Double(window.frame.width), forKey: "overlayWidth")
        UserDefaults.standard.set(Double(window.frame.height), forKey: "overlayHeight")
    }
    
    private func setupContent() {
        // Settings and the overlay observe the same live script collection.
        scriptManager = ScriptManager.shared
        scrollController = ScrollController(userDefaults: .standard)
        
        let contentView = OverlayContentView(
            scriptManager: scriptManager!,
            scrollController: scrollController!,
            onHover: { [weak self] isHovering in
                self?.handleHover(isHovering)
            },
            onDrag: { [weak self] translation, isEnded in
                self?.handleDrag(translation)
                if isEnded {
                    self?.dragTracker.reset()
                }
            },
            onResize: { [weak self] (widthDelta: CGFloat, heightDelta: CGFloat, isEnded: Bool) in
                self?.handleResize(widthDelta: widthDelta, heightDelta: heightDelta)
                if isEnded {
                    self?.resetResizeTracking()
                }
            }
        )
        
        window?.contentView = NSHostingView(rootView: contentView)
        
        // Connect scrollController to window for scroll wheel handling
        (window as? OverlayWindow)?.scrollController = scrollController
        
        // Handle end of script behavior
        scrollController?.onEndReached = { [weak self] in
            self?.scriptManager?.selectNextScript()
            self?.scrollController?.reset() // Reset progress for the new script
        }
        
        // Listen for settings changes to update overlay size in real-time
        // Throttled to avoid freezes during rapid clicks/drags
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.settingsDidChange()
            }
            .store(in: &cancellables)
        
    }
    
    private var lastResizeSize: CGSize?
    
    private func handleResize(widthDelta: CGFloat, heightDelta: CGFloat) {
        guard let window = window else { return }
        
        // Initialize tracking on first call
        if lastResizeSize == nil {
            lastResizeSize = window.frame.size
        }
        
        let baseSize = lastResizeSize!
        let newWidth = max(200, min(800, baseSize.width + widthDelta))
        let newHeight = max(80, min(600, baseSize.height + heightDelta))
        
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        
        let currentFrame = window.frame
        // Keep top edge flush with the monitor's top boundary
        let newY = screenFrame.maxY - newHeight
        
        window.setFrame(
            NSRect(x: currentFrame.origin.x, y: newY, width: newWidth, height: newHeight),
            display: true
        )
        
        // Save to UserDefaults for persistence
        UserDefaults.standard.set(Double(newWidth), forKey: "overlayWidth")
        UserDefaults.standard.set(Double(newHeight), forKey: "overlayHeight")
    }
    
    func resetResizeTracking() {
        lastResizeSize = nil
    }
    
    @objc private func settingsDidChange() {
        scrollController?.applyPersistedScrollSpeed()
        updateOverlaySize()
    }
    
    /// Update overlay window size based on current settings
    private func updateOverlaySize() {
        guard let window = window else { return }
        
        let newWidth = CGFloat(UserDefaults.standard.double(forKey: "overlayWidth") > 0 
                              ? UserDefaults.standard.double(forKey: "overlayWidth") : 350)
        let newHeight = CGFloat(UserDefaults.standard.double(forKey: "overlayHeight") > 0 
                               ? UserDefaults.standard.double(forKey: "overlayHeight") : 150)
        
        // Keep window centered horizontally on screen
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        
        // Calculate new position (centered horizontally, stuck to top)
        let newX = screenFrame.midX - newWidth / 2
        let newY = screenFrame.maxY - newHeight // Always at the very top of monitor
        
        // Respect the system's Reduce Motion setting for non-essential resizing.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.2
            window.animator().setFrame(
                NSRect(x: newX, y: newY, width: newWidth, height: newHeight),
                display: true
            )
        }
    }
    
    private func handleDrag(_ translation: CGPoint) {
        guard let window = window else { return }
        window.setFrameOrigin(
            dragTracker.origin(
                currentOrigin: window.frame.origin,
                translation: translation
            )
        )
    }
    
    private func setupManagers() {
        hotkeyManager = HotkeyManager()
        
        // Register global hotkeys
        hotkeyManager?.register(.speedUp) { [weak self] in
            self?.scrollController?.adjustPace(steps: 2)
        }
        
        hotkeyManager?.register(.speedDown) { [weak self] in
            self?.scrollController?.adjustPace(steps: -2)
        }
        
        hotkeyManager?.register(.togglePause) { [weak self] in
            self?.scrollController?.togglePause()
        }

        hotkeyManager?.register(.toggleVoiceFollow) {
            NotificationCenter.default.post(name: .toggleVoiceFollow, object: nil)
        }
        
        hotkeyManager?.register(.reset) { [weak self] in
            self?.scrollController?.reset()
        }
        
        hotkeyManager?.register(.toggleOverlay) { [weak self] in
            self?.toggleVisibility()
        }

        hotkeyManager?.register(.nextDisplay) { [weak self] in
            self?.moveToNextDisplay()
        }
    }

    func showOverlay() {
        window?.makeKeyAndOrderFront(nil)
    }

    func hideOverlay() {
        window?.orderOut(nil)
    }

    var isOverlayVisible: Bool {
        window?.isVisible ?? false
    }
    
    func toggleVisibility() {
        guard let window = window else { return }
        if window.isVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    func moveToNextDisplay() {
        let screens = NSScreen.screens
        guard let window, screens.count > 1 else { return }

        let currentIndex = window.screen.flatMap { currentScreen in
            screens.firstIndex { $0 === currentScreen }
        } ?? 0
        let nextScreen = screens[(currentIndex + 1) % screens.count]

        MacOSWindowManager().moveToScreen(window, screen: nextScreen)
    }

    private var wasPlayingBeforeHover = false
    
    private func handleHover(_ isHovering: Bool) {
        self.isHovering = isHovering
        
        guard let sc = scrollController else { return }
        
        if isHovering {
            // Save state before hover-pause
            wasPlayingBeforeHover = !sc.isPaused
            sc.pause()
        } else {
            // Only resume if it was playing before hover AND user didn't click pause
            if wasPlayingBeforeHover && !sc.wasManuallyPaused {
                sc.resume()
            }
        }
    }
}

/// Custom NSWindow subclass for overlay
class OverlayWindow: NSWindow {
    weak var scrollController: ScrollController?
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    override func scrollWheel(with event: NSEvent) {
        // Handle scroll wheel at window level
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 10
        scrollController?.scrollByDelta(delta)
        // Don't call super to prevent propagation
    }
}

/// SwiftUI content for the overlay
struct OverlayContentView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @ObservedObject var scriptManager: ScriptManager
    @ObservedObject var scrollController: ScrollController
    @StateObject private var speechRecognizer = OnDeviceSpeechRecognizer()
    @ObservedObject private var proStore = ProEntitlementStore.shared
    var onHover: (Bool) -> Void
    var onDrag: ((CGPoint, Bool) -> Void)?
    var onResize: ((CGFloat, CGFloat, Bool) -> Void)? // width delta, height delta, isEnded
    
    init(scriptManager: ScriptManager, scrollController: ScrollController, onHover: @escaping (Bool) -> Void, onDrag: ((CGPoint, Bool) -> Void)? = nil, onResize: ((CGFloat, CGFloat, Bool) -> Void)? = nil) {
        self.scriptManager = scriptManager
        self.scrollController = scrollController
        self.onHover = onHover
        self.onDrag = onDrag
        self.onResize = onResize
    }
    
    @AppStorage("overlayOpacity") private var opacity: Double = 0.85
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("focusModeIntensity") private var focusModeIntensity: Int = 0
    @AppStorage("textAlignment") private var textAlignment: Int = 1
    @AppStorage("fontFamily") private var fontFamily: Int = 0
    @AppStorage("mirrorText") private var mirrorText = false
    @AppStorage("stageDirectionStyle") private var stageDirectionStyle = 1
    
    @State private var showControls = false
    @State private var voiceMatcher: VoicePositionMatcher?

    private var lineHeight: CGFloat {
        max(28, CGFloat(fontSize) * 1.2 + 8)
    }

    private var displayedLines: [PromptLine] {
        if stageDirectionStyle == 2 {
            return scriptManager.promptLines.filter { !$0.isStageDirection }
        }
        return scriptManager.promptLines
    }

    private var pacedWordCount: Int {
        scriptManager.selectedScript?.wordCount(
            excludingStageDirections: stageDirectionStyle != 0
        ) ?? 0
    }
    
    // Convert text alignment setting to SwiftUI alignment
    private var alignment: Alignment {
        switch textAlignment {
        case 0: return .leading
        case 2: return .trailing
        default: return .center
        }
    }
    
    // Convert fontFamily setting to Font.Design
    private var fontDesign: Font.Design {
        switch fontFamily {
        case 1: return .monospaced
        case 2: return .serif
        case 3: return .rounded
        default: return .default
        }
    }
    
    // Compute edge opacity for focus mode
    private var focusModeEdgeOpacity: Double {
        switch focusModeIntensity {
        case 1: return 0.6   // Subtle
        case 2: return 0.35  // Medium
        case 3: return 0.15  // Strong
        default: return 1.0
        }
    }

    private var requiresOpaqueBackground: Bool {
        reduceTransparency || colorSchemeContrast == .increased
    }
    
    // Create gradient mask for focus mode (dims edges, bright center)
    @ViewBuilder
    private func focusModeGradient(height: CGFloat) -> some View {
        if focusModeIntensity == 0 || colorSchemeContrast == .increased {
            Rectangle().fill(.white)
        } else {
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(focusModeEdgeOpacity), location: 0.0),
                    .init(color: .white.opacity(min(1.0, focusModeEdgeOpacity * 1.5)), location: 0.25),
                    .init(color: .white, location: 0.4),
                    .init(color: .white, location: 0.6),
                    .init(color: .white.opacity(min(1.0, focusModeEdgeOpacity * 1.5)), location: 0.75),
                    .init(color: .white.opacity(focusModeEdgeOpacity), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Control bar with drag handle (shows on hover)
            if showControls {
                controlBar
            }

            // Measure only the prompt viewport. The control bar changes the
            // available height, and pace calculations must use that real area.
            GeometryReader { geometry in
                let readingEdgePadding = max(0, geometry.size.height / 2 - lineHeight / 2)

                ZStack {
                    // Background
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: 0
                    )
                    .fill(.black.opacity(requiresOpaqueBackground ? 1 : opacity))
                    
                    // Fixed-position container for the scrolling content
                    // This allows the mask to stay centered in the window
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: readingEdgePadding)

                            VStack(alignment: alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center), spacing: 8) {
                                ForEach(Array(displayedLines.enumerated()), id: \.element.id) { displayIndex, promptLine in
                                    Text(promptLine.text)
                                        .font(.system(size: fontSize, weight: .semibold, design: fontDesign))
                                        .foregroundColor(
                                            .white.opacity(
                                                promptLine.isStageDirection && stageDirectionStyle == 1 ? 0.5 : 1
                                            )
                                        )
                                        .shadow(color: .black, radius: 1, x: 0, y: 1)
                                        .frame(maxWidth: .infinity, alignment: alignment)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(
                                                    scrollController.highlightedLine == promptLine.sourceIndex
                                                        ? Color.yellow
                                                        : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            scrollController.jumpToLine(
                                                displayIndex,
                                                highlightedLineIndex: promptLine.sourceIndex,
                                                autoResumeAfter: 1.0
                                            )
                                            resetVoiceMatcher(nearLineIndex: promptLine.sourceIndex)
                                        }
                                }
                            }
                            .padding(.horizontal, 16)

                            Color.clear
                                .frame(height: readingEdgePadding)
                        }
                        .offset(y: -scrollController.scrollOffset)
                        .scaleEffect(x: mirrorText ? -1 : 1, y: 1, anchor: .center)
                        .animation(.linear(duration: 0.016), value: scrollController.scrollOffset)
                        .background(
                            GeometryReader { contentGeo in
                                Color.clear
                                    .onAppear {
                                        updateContentHeight(contentGeo.size.height, visibleHeight: geometry.size.height)
                                    }
                                    .onChange(of: contentGeo.size.height) { newHeight in
                                        updateContentHeight(newHeight, visibleHeight: geometry.size.height)
                                    }
                            }
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .contentShape(Rectangle())
                    .clipped() // Ensure content doesn't bleed out during resize
                    .mask(focusModeGradient(height: geometry.size.height))
                    
                    // Center line indicator
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(.yellow.opacity(0.12))
                            .frame(height: lineHeight + 12)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .allowsHitTesting(false)

                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.8))
                        .frame(
                            width: max(0, geometry.size.width - 14),
                            height: geometry.size.height,
                            alignment: .leading
                        )
                        .padding(.horizontal, 7)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    VStack {
                        Spacer()
                        ProgressView(value: scrollController.progress)
                            .progressViewStyle(.linear)
                            .tint(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 2)
                            .accessibilityLabel("Script progress")
                            .accessibilityValue("\(Int(scrollController.progress * 100)) percent")
                    }
                    .allowsHitTesting(false)

                    VStack {
                        HStack {
                            Spacer()
                            Label(overlayStatusText, systemImage: overlayStatusIcon)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(.black.opacity(requiresOpaqueBackground ? 1 : 0.45))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(7)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        speechRecognizer.state == .idle ? "Remaining time" : "Voice Follow"
                    )
                    .accessibilityValue(overlayStatusText)
                    
                    // Pause indicator
                    if scrollController.isPaused && !showControls {
                        VStack {
                            HStack(spacing: 8) {
                                Image(systemName: scrollController.scrollOffset == 0 ? "play.circle.fill" : "pause.circle.fill")
                                    .accessibilityHidden(true)
                                Text(scrollController.scrollOffset == 0 ? "READY" : "PAUSED")
                                    .font(.system(.caption, design: .monospaced).bold())
                                Spacer()
                            }
                            .foregroundColor(.white.opacity(0.85))
                            Spacer()
                        }
                        .padding(7)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 0))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                showControls = hovering
            }
            onHover(hovering)
        }
        .onAppear {
            scrollController.updateWordCount(pacedWordCount)
        }
        .onDisappear {
            speechRecognizer.stop()
            voiceMatcher = nil
        }
        .onChange(of: scriptManager.selectedScript?.content) { _ in
            scrollController.updateWordCount(pacedWordCount)
            if speechRecognizer.state.isEngaged {
                speechRecognizer.stop()
                voiceMatcher = nil
            }
        }
        .onChange(of: stageDirectionStyle) { _ in
            scrollController.updateWordCount(pacedWordCount)
        }
        .onChange(of: scrollController.isPaused) { isPaused in
            if speechRecognizer.state.isEngaged && !isPaused {
                scrollController.pause()
            }
        }
        .onChange(of: speechRecognizer.latestTranscript) { transcript in
            consumeVoiceTranscript(transcript)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleVoiceFollow)) { _ in
            toggleVoiceFollow()
        }
        .task {
            await proStore.prepare()
        }
    }
    
    private func updateContentHeight(_ height: CGFloat, visibleHeight: CGFloat) {
        scrollController.updateContentMetrics(
            contentHeight: height,
            visibleHeight: visibleHeight,
            wordCount: pacedWordCount
        )
    }
    
    private var controlBar: some View {
        HStack(spacing: 8) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            onDrag?(
                                CGPoint(x: value.translation.width, y: value.translation.height),
                                false
                            )
                        }
                        .onEnded { value in
                            onDrag?(
                                CGPoint(x: value.translation.width, y: value.translation.height),
                                true
                            )
                        }
                )
            
            Divider()
                .frame(height: 16)
                .background(.white.opacity(0.3))
            
            // Play/Pause
            Button(action: { scrollController.togglePause() }) {
                Image(systemName: scrollController.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(speechRecognizer.state.isEngaged)
            .help(scrollController.isPaused ? "Start scrolling" : "Pause scrolling")
            .accessibilityLabel(scrollController.isPaused ? "Start scrolling" : "Pause scrolling")
            
            Divider()
                .frame(height: 16)
                .background(.white.opacity(0.3))

            Button(action: toggleVoiceFollow) {
                Image(
                    systemName: speechRecognizer.state.isListening
                        ? "waveform.circle.fill"
                        : "waveform.circle"
                )
                .foregroundColor(speechRecognizer.state.isListening ? .yellow : .white)
                .font(.system(size: 16))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(speechRecognizer.state == .requestingPermission)
            .help(
                speechRecognizer.state.isListening
                    ? "Stop Voice Follow"
                    : "Start on-device Voice Follow"
            )
            .accessibilityLabel(
                speechRecognizer.state.isListening
                    ? "Stop Voice Follow"
                    : "Start Voice Follow"
            )
            .accessibilityValue(voiceStatusLabel)

            Divider()
                .frame(height: 16)
                .background(.white.opacity(0.3))
            
            // Speed controls - bigger tap targets
            Button(action: { scrollController.adjustPace(steps: -1) }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(speechRecognizer.state.isEngaged)
            .help("Slower")
            .accessibilityLabel("Slower")
            
            Text(scrollController.paceControlLabel)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .frame(minWidth: 34)
                .accessibilityLabel("Pace")
                .accessibilityValue(scrollController.paceControlLabel)
            
            Button(action: { scrollController.adjustPace(steps: 1) }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(speechRecognizer.state.isEngaged)
            .help("Faster")
            .accessibilityLabel("Faster")
            
            Spacer()
            
            // Reset
            Button(action: resetPromptPosition) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reset to the beginning")
            .accessibilityLabel("Reset to the beginning")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(requiresOpaqueBackground ? 1 : 0.7))
        .foregroundColor(.white)
    }

    private var remainingTimeText: String {
        guard let remainingTime = scrollController.remainingTime else { return "—" }
        let totalSeconds = max(0, Int(ceil(remainingTime)))
        if totalSeconds >= 3_600 {
            return String(
                format: "%d:%02d:%02d",
                totalSeconds / 3_600,
                (totalSeconds % 3_600) / 60,
                totalSeconds % 60
            )
        }
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var overlayStatusText: String {
        switch speechRecognizer.state {
        case .idle:
            return remainingTimeText
        case .requestingPermission:
            return "Preparing voice"
        case .listening:
            return "Voice \(Int(scrollController.progress * 100))%"
        case .permissionDenied:
            return "Voice permission denied"
        case .unsupported(let localeIdentifier):
            return "No on-device \(localeIdentifier)"
        case .failed:
            return "Voice stopped"
        }
    }

    private var overlayStatusIcon: String {
        speechRecognizer.state == .idle ? "clock" : "waveform"
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
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowSettings"),
                object: nil
            )
            return
        }
        guard let script = scriptManager.selectedScript else { return }

        scrollController.manualPause()
        voiceMatcher = VoicePositionMatcher(
            tokens: script.tokens,
            startTokenIndex: voiceStartTokenIndex(for: script)
        )

        Task {
            await speechRecognizer.start(scriptText: script.content)
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
    }

    private func voiceStartTokenIndex(for script: Script) -> Int {
        guard !script.tokens.isEmpty, scrollController.progress > 0 else { return -1 }
        return min(
            script.tokens.count - 1,
            Int((scrollController.progress * Double(script.tokens.count - 1)).rounded(.down))
        )
    }

    private func resetPromptPosition() {
        scrollController.reset()
        if var matcher = voiceMatcher {
            matcher.reset()
            voiceMatcher = matcher
        }
    }

    private func resetVoiceMatcher(nearLineIndex lineIndex: Int) {
        guard speechRecognizer.state.isEngaged,
              let script = scriptManager.selectedScript,
              var matcher = voiceMatcher else { return }

        let firstTokenOnOrAfterLine = script.tokens.firstIndex {
            $0.lineIndex >= lineIndex
        } ?? script.tokens.count
        matcher.reset(nearTokenIndex: firstTokenOnOrAfterLine - 1)
        voiceMatcher = matcher
    }
}
