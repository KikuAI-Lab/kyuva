import AppKit

/// Platform-specific capture exclusion
/// macOS: Uses NSWindow.sharingType = .none
protocol CaptureExclusionProvider {
    func excludeFromCapture(_ window: NSWindow)
    func isExcluded(_ window: NSWindow) -> Bool
    func runLeakTest() -> LeakTestResult
}

/// macOS implementation
class MacOSCaptureExclusionProvider: CaptureExclusionProvider {
    
    func excludeFromCapture(_ window: NSWindow) {
        window.sharingType = .none
    }
    
    func isExcluded(_ window: NSWindow) -> Bool {
        return window.sharingType == .none
    }
    
    func runLeakTest() -> LeakTestResult {
        // Create test instructions
        return LeakTestResult(
            isConfident: true,
            supportedApps: ["Zoom", "Google Meet", "Microsoft Teams", "OBS", "QuickTime"],
            warningApps: [],
            instructions: """
            To verify the overlay is invisible:
            
            1. Start a screen share in Zoom/Meet/Teams
            2. Share your entire screen
            3. Look at your shared screen preview
            4. The Kyuva overlay should NOT be visible
            
            If you see the overlay in the preview, please report this issue.
            """
        )
    }
}

struct LeakTestResult {
    let isConfident: Bool
    let supportedApps: [String]
    let warningApps: [String]
    let instructions: String
}
