import AppKit
import SwiftUI
import Combine

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
            onDrag: { [weak self] translation in
                self?.handleDrag(translation)
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
        
        // Animate the resize
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().setFrame(
                NSRect(x: newX, y: newY, width: newWidth, height: newHeight),
                display: true
            )
        }
    }
    
    private func handleDrag(_ translation: CGPoint) {
        guard let window = window else { return }
        let currentFrame = window.frame
        let newOrigin = CGPoint(
            x: currentFrame.origin.x + translation.x,
            y: currentFrame.origin.y - translation.y
        )
        window.setFrameOrigin(newOrigin)
    }
    
    /// Move overlay to built-in MacBook screen (if available)
    func moveToBuiltInScreen() {
        // Find the built-in screen (usually the MacBook display)
        let builtInScreen = NSScreen.screens.first { screen in
            // Built-in displays typically have localizedName containing "Built-in"
            screen.localizedName.contains("Built-in") || screen.localizedName.contains("MacBook")
        } ?? NSScreen.main ?? NSScreen.screens.first!
        
        let screenFrame = builtInScreen.frame
        let width: CGFloat = 400
        let height: CGFloat = 150
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height - 30
        
        window?.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: true)
    }
    
    private func setupManagers() {
        hotkeyManager = HotkeyManager()
        
        // Register global hotkeys
        hotkeyManager?.register(.speedUp) { [weak self] in
            self?.scrollController?.adjustSpeed(delta: 10)
        }
        
        hotkeyManager?.register(.speedDown) { [weak self] in
            self?.scrollController?.adjustSpeed(delta: -10)
        }
        
        hotkeyManager?.register(.togglePause) { [weak self] in
            self?.scrollController?.togglePause()
        }
        
        hotkeyManager?.register(.reset) { [weak self] in
            self?.scrollController?.reset()
        }
        
        hotkeyManager?.register(.toggleOverlay) { [weak self] in
            self?.toggleVisibility()
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
    @ObservedObject var scriptManager: ScriptManager
    @ObservedObject var scrollController: ScrollController
    var onHover: (Bool) -> Void
    var onDrag: ((CGPoint) -> Void)?
    var onResize: ((CGFloat, CGFloat, Bool) -> Void)? // width delta, height delta, isEnded
    
    init(scriptManager: ScriptManager, scrollController: ScrollController, onHover: @escaping (Bool) -> Void, onDrag: ((CGPoint) -> Void)? = nil, onResize: ((CGFloat, CGFloat, Bool) -> Void)? = nil) {
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
    
    @State private var showControls = false
    @State private var contentHeight: CGFloat = 0
    
    private let lineHeight: CGFloat = 28
    
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
    
    // Create gradient mask for focus mode (dims edges, bright center)
    @ViewBuilder
    private func focusModeGradient(height: CGFloat) -> some View {
        if focusModeIntensity == 0 {
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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Control bar with drag handle (shows on hover)
                if showControls {
                    controlBar
                }
                
                // Main content
                ZStack {
                    // Background
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: 0
                    )
                    .fill(.black.opacity(opacity))
                    
                    // Fixed-position container for the scrolling content
                    // This allows the mask to stay centered in the window
                    ZStack {
                        VStack(alignment: alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center), spacing: 8) {
                            ForEach(Array(scriptManager.lines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(size: fontSize, weight: .semibold, design: fontDesign))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1, x: 0, y: 1)
                                    .frame(maxWidth: .infinity, alignment: alignment)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(scrollController.highlightedLine == index 
                                                  ? Color.yellow.opacity(0.4) 
                                                  : Color.clear)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        scrollController.jumpToLine(index, autoResumeAfter: 1.0)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, geometry.size.height)
                        .offset(y: -scrollController.scrollOffset + geometry.size.height / 2)
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
                    
                    // Pause indicator
                    if scrollController.isPaused && !showControls {
                        VStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Image(systemName: scrollController.scrollOffset == 0 ? "play.circle.fill" : "pause.circle.fill")
                                Text(scrollController.scrollOffset == 0 ? "READY" : "PAUSED")
                                    .font(.system(.caption, design: .monospaced).bold())
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 0))
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                showControls = hovering
            }
            onHover(hovering)
        }
    }
    
    private func updateContentHeight(_ height: CGFloat, visibleHeight: CGFloat) {
        contentHeight = height
        scrollController.contentHeight = height
        scrollController.visibleHeight = visibleHeight
    }
    
    private var controlBar: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            onDrag?(CGPoint(x: value.translation.width, y: value.translation.height))
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
            
            Divider()
                .frame(height: 16)
                .background(.white.opacity(0.3))
            
            // Speed controls - bigger tap targets
            Button(action: { scrollController.adjustSpeed(delta: -5) }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Text("\(Int(scrollController.scrollSpeed))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 30)
            
            Button(action: { scrollController.adjustSpeed(delta: 5) }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Reset
            Button(action: { scrollController.reset() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.7))
        .foregroundColor(.white)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Scroll Wheel Event

struct ScrollWheelReceiver: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> ScrollWheelCaptureView {
        let view = ScrollWheelCaptureView()
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: ScrollWheelCaptureView, context: Context) {
        nsView.onScroll = onScroll
    }
}

class ScrollWheelCaptureView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func scrollWheel(with event: NSEvent) {
        // Use scrollingDeltaY for smooth trackpad, deltaY for mouse wheel
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 10
        onScroll?(delta)
    }
}

// Remove old unused code
struct ScrollWheelModifier: ViewModifier {
    var onScroll: (CGFloat) -> Void
    
    func body(content: Content) -> some View {
        content // No longer used
    }
}

struct ScrollWheelHandler: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func onScrollWheelEvent(_ handler: @escaping (CGFloat) -> Void) -> some View {
        self
    }
}
