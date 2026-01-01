import Foundation
import Combine

/// Controls smooth continuous scroll with pixel-perfect animation
class ScrollController: ObservableObject {
    
    /// Current scroll offset in pixels (animated smoothly)
    @Published var scrollOffset: CGFloat = 0
    
    @Published var isPaused: Bool = true // Start paused
    @Published var scrollSpeed: Double = 30 // pixels per second
    
    /// Highlighted line index (for flash animation on click)
    @Published var highlightedLine: Int? = nil
    
    /// Total content height (set by view)
    var contentHeight: CGFloat = 1000
    
    /// Visible height (set by view)
    var visibleHeight: CGFloat = 150
    
    /// Line height for calculations
    let lineHeight: CGFloat = 28
    
    private var displayLink: Timer?
    private var lastUpdateTime: Date = Date()
    private var autoResumeWorkItem: DispatchWorkItem?
    
    init() {
        startDisplayLink()
    }
    
    deinit {
        displayLink?.invalidate()
        autoResumeWorkItem?.cancel()
    }
    
    // MARK: - Display Link (60fps)
    
    private func startDisplayLink() {
        displayLink?.invalidate()
        lastUpdateTime = Date()
        
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(displayLink!, forMode: .common)
    }
    
    private func tick() {
        guard !isPaused else {
            lastUpdateTime = Date()
            return
        }
        
        let now = Date()
        let dt = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now
        
        // Smooth increment
        let increment = CGFloat(scrollSpeed) * CGFloat(dt)
        scrollOffset += increment
        
        // Clamp to content bounds
        let maxOffset = max(0, contentHeight - visibleHeight)
        if scrollOffset > maxOffset {
            scrollOffset = maxOffset
            isPaused = true // Auto-pause at end
        }
        if scrollOffset < 0 {
            scrollOffset = 0
        }
    }
    
    // MARK: - Controls
    
    func pause() {
        isPaused = true
        autoResumeWorkItem?.cancel()
    }
    
    func resume() {
        isPaused = false
        lastUpdateTime = Date()
    }
    
    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }
    
    func reset() {
        scrollOffset = 0
        isPaused = true
        highlightedLine = nil
        autoResumeWorkItem?.cancel()
    }
    
    func adjustSpeed(delta: Double) {
        scrollSpeed = max(5, min(150, scrollSpeed + delta))
    }
    
    /// Jump to line with flash highlight and auto-resume after delay
    func jumpToLine(_ lineIndex: Int, autoResumeAfter: TimeInterval = 1.0) {
        let wasPlaying = !isPaused
        
        // Jump to the line
        scrollOffset = max(0, CGFloat(lineIndex) * lineHeight)
        lastUpdateTime = Date()
        
        // Flash highlight
        highlightedLine = lineIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.highlightedLine = nil
        }
        
        // If was playing, pause briefly then auto-resume
        if wasPlaying {
            isPaused = true
            
            autoResumeWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.resume()
            }
            autoResumeWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + autoResumeAfter, execute: workItem)
        }
    }
    
    /// Scroll by delta (for mouse wheel)
    func scrollByDelta(_ delta: CGFloat) {
        scrollOffset = max(0, scrollOffset - delta)
        
        // Clamp
        let maxOffset = max(0, contentHeight - visibleHeight)
        scrollOffset = min(scrollOffset, maxOffset)
    }
    
    /// Jump to specific pixel offset (legacy)
    func goToOffset(_ offset: CGFloat) {
        scrollOffset = max(0, offset)
        lastUpdateTime = Date()
    }
    
    /// Current line index based on offset
    var currentLineIndex: Int {
        Int(scrollOffset / lineHeight)
    }
}
