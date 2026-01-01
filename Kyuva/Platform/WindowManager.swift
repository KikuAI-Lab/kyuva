import AppKit

/// Platform-specific window management
protocol WindowManagerProtocol {
    func makeAlwaysOnTop(_ window: NSWindow)
    func moveToScreen(_ window: NSWindow, screen: NSScreen)
    func positionNearCamera(_ window: NSWindow)
}

/// macOS window manager
class MacOSWindowManager: WindowManagerProtocol {
    
    func makeAlwaysOnTop(_ window: NSWindow) {
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    func moveToScreen(_ window: NSWindow, screen: NSScreen) {
        let screenFrame = screen.frame
        let windowFrame = window.frame
        
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.maxY - windowFrame.height - 30
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func positionNearCamera(_ window: NSWindow) {
        // MacBooks with notch: camera is at top center
        // External displays: assume webcam is at top center
        guard let screen = window.screen ?? NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let windowFrame = window.frame
        
        // Position just below the notch/camera area
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.maxY - windowFrame.height - 30
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
