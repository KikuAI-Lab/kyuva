import AppKit
import SwiftUI

/// Controller for the invisible overlay window
/// Key feature: window is excluded from screen capture
class OverlayWindowController: NSWindowController {
    
    private var scrollController: ScrollController?
    private var scriptManager: ScriptManager?
    private var hotkeyManager: HotkeyManager?
    private var isHovering = false
    
    convenience init() {
        // Get screen with notch (main screen on MacBooks with notch)
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        // Position at top center (notch area on MacBooks)
        let width: CGFloat = 400
        let height: CGFloat = 150
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height - 30 // Below notch
        
        let window = OverlayWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        
        setupWindow(window)
        setupContent()
        setupManagers()
    }
    
    private func setupWindow(_ window: NSWindow) {
        // CRITICAL: Exclude from screen capture (Zoom, Meet, OBS, etc.)
        window.sharingType = .none
        
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
    }
    
    private func setupContent() {
        scriptManager = ScriptManager()
        scrollController = ScrollController()
        
        let contentView = OverlayContentView(
            scriptManager: scriptManager!,
            scrollController: scrollController!,
            onHover: { [weak self] isHovering in
                self?.handleHover(isHovering)
            },
            onDrag: { [weak self] translation in
                self?.handleDrag(translation)
            }
        )
        
        window?.contentView = NSHostingView(rootView: contentView)
        
        // Connect scrollController to window for scroll wheel handling
        (window as? OverlayWindow)?.scrollController = scrollController
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
    }
    
    private func handleHover(_ isHovering: Bool) {
        self.isHovering = isHovering
        if isHovering {
            scrollController?.pause()
        } else {
            scrollController?.resume()
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
    
    @AppStorage("overlayOpacity") private var opacity: Double = 0.85
    @AppStorage("fontSize") private var fontSize: Double = 18
    
    @State private var showControls = false
    @State private var contentHeight: CGFloat = 0
    
    private let lineHeight: CGFloat = 28
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Control bar with drag handle (shows on hover)
                if showControls {
                    controlBar
                }
                
                // Main content with TRUE smooth scroll (no ScrollView)
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: showControls ? 0 : 12)
                        .fill(.black.opacity(opacity))
                    
                    // Scrolling text container (clipped)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(scriptManager.lines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: fontSize, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 1, x: 0, y: 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: lineHeight)
                                .padding(.horizontal, 4)
                                .background(
                                    // Flash highlight when clicked
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(scrollController.highlightedLine == index 
                                              ? Color.yellow.opacity(0.5) 
                                              : Color.clear)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Click to jump with highlight and auto-resume
                                    scrollController.jumpToLine(index, autoResumeAfter: 1.0)
                                }
                                .animation(.easeOut(duration: 0.3), value: scrollController.highlightedLine)
                        }
                    }
                    .padding(.horizontal, 8)
                    .offset(y: -scrollController.scrollOffset + geometry.size.height / 2 - lineHeight / 2)
                    .background(
                        GeometryReader { contentGeo in
                            Color.clear.onAppear {
                                contentHeight = contentGeo.size.height
                                scrollController.contentHeight = contentHeight
                                scrollController.visibleHeight = geometry.size.height
                            }
                        }
                    )
                    
                    // Center line indicator
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(.yellow.opacity(0.2))
                            .frame(height: lineHeight + 4)
                        Spacer()
                    }
                    
                    // Pause indicator
                    if scrollController.isPaused && !showControls {
                        VStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: scrollController.scrollOffset == 0 ? "play.fill" : "pause.fill")
                                Text(scrollController.scrollOffset == 0 ? "TAP ▶ TO START" : "PAUSED")
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.85))
                            .foregroundColor(.yellow)
                            .cornerRadius(6)
                            .padding(.bottom, 10)
                        }
                    }
                }
                .clipped()
                // Scroll wheel is now handled by OverlayWindow.scrollWheel()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                showControls = hovering
            }
            onHover(hovering)
        }
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
                    .font(.body)
            }
            .buttonStyle(.plain)
            
            // Speed controls
            Button(action: { scrollController.adjustSpeed(delta: -5) }) {
                Image(systemName: "minus")
            }
            .buttonStyle(.plain)
            
            Text("\(Int(scrollController.scrollSpeed))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 25)
            
            Button(action: { scrollController.adjustSpeed(delta: 5) }) {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Reset
            Button(action: { scrollController.reset() }) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.6))
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

