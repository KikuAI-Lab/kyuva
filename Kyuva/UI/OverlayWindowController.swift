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
            }
        )
        
        window?.contentView = NSHostingView(rootView: contentView)
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
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// SwiftUI content for the overlay
struct OverlayContentView: View {
    @ObservedObject var scriptManager: ScriptManager
    @ObservedObject var scrollController: ScrollController
    var onHover: (Bool) -> Void
    
    @AppStorage("overlayOpacity") private var opacity: Double = 0.85
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("textColor") private var textColorHex: String = "#FFFFFF"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(opacity))
                
                // Scrolling text
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(scriptManager.lines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(size: fontSize, weight: .medium))
                                    .foregroundColor(Color(hex: textColorHex))
                                    .opacity(lineOpacity(for: index))
                                    .id(index)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: scrollController.currentLineIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .onHover { hovering in
            onHover(hovering)
        }
    }
    
    private func lineOpacity(for index: Int) -> Double {
        let distance = abs(index - scrollController.currentLineIndex)
        switch distance {
        case 0: return 1.0
        case 1: return 0.7
        case 2: return 0.4
        default: return 0.2
        }
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
