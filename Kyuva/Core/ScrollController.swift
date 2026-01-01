import Foundation
import Combine

/// Controls scroll position and animation
class ScrollController: ObservableObject {
    
    @Published var currentLineIndex: Int = 0
    @Published var isPaused: Bool = false
    @Published var scrollSpeed: Double = 50 // pixels per second
    
    private var timer: Timer?
    private var accumulatedTime: Double = 0
    private let linesPerScroll = 1
    
    init() {
        startAutoScroll()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Auto Scroll
    
    func startAutoScroll() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        guard !isPaused else { return }
        
        accumulatedTime += 0.1
        let secondsPerLine = 100 / scrollSpeed
        
        if accumulatedTime >= secondsPerLine {
            accumulatedTime = 0
            advance(by: linesPerScroll)
        }
    }
    
    // MARK: - Controls
    
    func pause() {
        isPaused = true
    }
    
    func resume() {
        isPaused = false
    }
    
    func togglePause() {
        isPaused.toggle()
    }
    
    func reset() {
        currentLineIndex = 0
        accumulatedTime = 0
    }
    
    func adjustSpeed(delta: Double) {
        scrollSpeed = max(10, min(200, scrollSpeed + delta))
    }
    
    func advance(by lines: Int) {
        currentLineIndex += lines
    }
    
    func goTo(line: Int) {
        currentLineIndex = max(0, line)
    }
    
    // MARK: - Voice Sync
    
    /// Called by VoiceSyncEngine when speech matches a line
    func syncToLine(_ lineIndex: Int, confidence: Double) {
        // Anti-jitter: only move forward, max 2 lines jump
        guard lineIndex > currentLineIndex else { return }
        guard lineIndex - currentLineIndex <= 3 else { return }
        guard confidence > 0.6 else { return }
        
        currentLineIndex = lineIndex
        accumulatedTime = 0
    }
}
