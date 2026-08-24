import Foundation
import Combine
import SwiftUI

enum ScrollPaceMode: Int, CaseIterable, Identifiable {
    case fixedSpeed = 0
    case wordsPerMinute = 1
    case targetDuration = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fixedSpeed: return "Fixed"
        case .wordsPerMinute: return "WPM"
        case .targetDuration: return "Duration"
        }
    }
}

/// Controls smooth continuous scroll with pixel-perfect animation
class ScrollController: ObservableObject {
    static let minimumSpeed: Double = 10
    static let maximumSpeed: Double = 200
    static let minimumWordsPerMinute: Double = 60
    static let maximumWordsPerMinute: Double = 240
    static let minimumTargetDuration: TimeInterval = 30
    static let maximumTargetDuration: TimeInterval = 3_600

    static let paceModeDefaultsKey = "scrollPaceMode"
    static let speedDefaultsKey = "scrollSpeed"
    static let wordsPerMinuteDefaultsKey = "wordsPerMinute"
    static let targetDurationDefaultsKey = "targetDurationSeconds"
    
    /// Current scroll offset in pixels (animated smoothly)
    @Published var scrollOffset: CGFloat = 0
    
    @Published var isPaused: Bool = true // Start paused
    @Published private(set) var scrollSpeed: Double = 50
    @Published private(set) var paceMode: ScrollPaceMode = .fixedSpeed
    @Published private(set) var wordsPerMinute: Double = 150
    @Published private(set) var targetDurationSeconds: TimeInterval = 300
    
    /// Highlighted line index (for flash animation on click)
    @Published var highlightedLine: Int? = nil
    
    /// Track if user manually paused (vs hover-pause)
    var wasManuallyPaused: Bool = false
    
    /// Total content height (set by view)
    private(set) var contentHeight: CGFloat = 1000
    
    /// Visible height (set by view)
    private(set) var visibleHeight: CGFloat = 150
    
    /// Line height for calculations
    let lineHeight: CGFloat = 28
    
    private var autoResumeWorkItem: DispatchWorkItem?
    private var scrollTimer: Timer?
    private var lastUpdateTime: Date = Date()
    private let userDefaults: UserDefaults
    private var fixedScrollSpeed: Double = 50
    private var wordCount = 0
    
    init(startTimer: Bool = true, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        loadPaceSettings(from: userDefaults)

        if startTimer {
            startScrollTimer()
        }
    }
    
    deinit {
        scrollTimer?.invalidate()
        autoResumeWorkItem?.cancel()
    }
    
    // MARK: - Scroll Timer (High frequency for smooth updates)
    
    private func startScrollTimer() {
        scrollTimer?.invalidate()
        lastUpdateTime = Date()
        
        // 60fps timer - SwiftUI will interpolate smoothly
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(scrollTimer!, forMode: .common)
    }
    
    @AppStorage("endBehavior") private var endBehavior: Int = 0
    var onEndReached: (() -> Void)?

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
        let maxOffset = maximumOffset
        if scrollOffset >= maxOffset {
            switch endBehavior {
            case 1: // Start Over
                scrollOffset = 0
            case 2: // Play Next
                isPaused = true
                onEndReached?()
            default: // Do Nothing (Stay at end)
                scrollOffset = maxOffset
                isPaused = true
            }
        }
        if scrollOffset < 0 {
            scrollOffset = 0
        }
    }
    
    // MARK: - Controls

    /// Apply persisted pace settings without advancing the scroll position.
    /// This is also used when UserDefaults changes while the overlay is visible.
    func applyPersistedScrollSpeed(from userDefaults: UserDefaults? = nil) {
        loadPaceSettings(from: userDefaults ?? self.userDefaults)
    }
    
    func pause() {
        isPaused = true
        autoResumeWorkItem?.cancel()
    }
    
    /// Pause triggered by user action (button/hotkey)
    func manualPause() {
        wasManuallyPaused = true
        pause()
    }
    
    func resume() {
        guard maximumOffset > 0, scrollSpeed > 0 else {
            isPaused = true
            return
        }
        isPaused = false
        wasManuallyPaused = false
        lastUpdateTime = Date()
    }
    
    func togglePause() {
        if isPaused {
            resume()
        } else {
            manualPause()
        }
    }
    
    func reset() {
        scrollOffset = 0
        isPaused = true
        highlightedLine = nil
        autoResumeWorkItem?.cancel()
    }
    
    func adjustSpeed(delta: Double) {
        fixedScrollSpeed = Self.clampedSpeed(fixedScrollSpeed + delta)
        userDefaults.set(fixedScrollSpeed, forKey: Self.speedDefaultsKey)
        recalculateScrollSpeed()
    }

    /// Positive steps make the current mode faster; negative steps make it slower.
    func adjustPace(steps: Double) {
        guard steps != 0 else { return }

        switch paceMode {
        case .fixedSpeed:
            fixedScrollSpeed = Self.clampedSpeed(fixedScrollSpeed + steps * 5)
            userDefaults.set(fixedScrollSpeed, forKey: Self.speedDefaultsKey)
        case .wordsPerMinute:
            wordsPerMinute = Self.clampedWordsPerMinute(wordsPerMinute + steps * 5)
            userDefaults.set(wordsPerMinute, forKey: Self.wordsPerMinuteDefaultsKey)
        case .targetDuration:
            targetDurationSeconds = Self.clampedTargetDuration(
                targetDurationSeconds - steps * 30
            )
            userDefaults.set(targetDurationSeconds, forKey: Self.targetDurationDefaultsKey)
        }

        recalculateScrollSpeed()
    }

    private static func clampedSpeed(_ speed: Double) -> Double {
        min(maximumSpeed, max(minimumSpeed, speed))
    }

    private static func clampedWordsPerMinute(_ value: Double) -> Double {
        min(maximumWordsPerMinute, max(minimumWordsPerMinute, value))
    }

    private static func clampedTargetDuration(_ value: TimeInterval) -> TimeInterval {
        min(maximumTargetDuration, max(minimumTargetDuration, value))
    }
    
    /// Jump to line with flash highlight and auto-resume after delay
    func jumpToLine(
        _ lineIndex: Int,
        highlightedLineIndex: Int? = nil,
        autoResumeAfter: TimeInterval = 1.0
    ) {
        let wasPlaying = !isPaused
        
        // Jump to the line
        scrollOffset = min(maximumOffset, max(0, CGFloat(lineIndex) * lineHeight))
        lastUpdateTime = Date()
        
        // Flash highlight
        highlightedLine = highlightedLineIndex ?? lineIndex
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
        scrollOffset = min(scrollOffset, maximumOffset)
    }
    
    /// Jump to specific pixel offset (legacy)
    func goToOffset(_ offset: CGFloat) {
        scrollOffset = min(maximumOffset, max(0, offset))
        lastUpdateTime = Date()
    }

    func updateContentMetrics(
        contentHeight: CGFloat,
        visibleHeight: CGFloat,
        wordCount: Int
    ) {
        self.contentHeight = max(0, contentHeight)
        self.visibleHeight = max(0, visibleHeight)
        self.wordCount = max(0, wordCount)
        scrollOffset = min(scrollOffset, maximumOffset)
        recalculateScrollSpeed()
    }

    func updateWordCount(_ wordCount: Int) {
        self.wordCount = max(0, wordCount)
        recalculateScrollSpeed()
    }

    var maximumOffset: CGFloat {
        max(0, contentHeight - visibleHeight)
    }

    var progress: Double {
        guard maximumOffset > 0 else { return 0 }
        return min(1, max(0, Double(scrollOffset / maximumOffset)))
    }

    var remainingTime: TimeInterval? {
        guard scrollSpeed > 0 else { return nil }
        return Double(max(0, maximumOffset - scrollOffset)) / scrollSpeed
    }

    var paceControlLabel: String {
        switch paceMode {
        case .fixedSpeed:
            return "\(Int(fixedScrollSpeed))"
        case .wordsPerMinute:
            return "\(Int(wordsPerMinute))w"
        case .targetDuration:
            let totalSeconds = Int(targetDurationSeconds.rounded())
            return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
        }
    }
    
    /// Current line index based on offset
    var currentLineIndex: Int {
        Int(scrollOffset / lineHeight)
    }

    private func loadPaceSettings(from defaults: UserDefaults) {
        paceMode = ScrollPaceMode(
            rawValue: defaults.integer(forKey: Self.paceModeDefaultsKey)
        ) ?? .fixedSpeed

        if defaults.object(forKey: Self.speedDefaultsKey) != nil {
            fixedScrollSpeed = Self.clampedSpeed(
                defaults.double(forKey: Self.speedDefaultsKey)
            )
        }
        if defaults.object(forKey: Self.wordsPerMinuteDefaultsKey) != nil {
            wordsPerMinute = Self.clampedWordsPerMinute(
                defaults.double(forKey: Self.wordsPerMinuteDefaultsKey)
            )
        }
        if defaults.object(forKey: Self.targetDurationDefaultsKey) != nil {
            targetDurationSeconds = Self.clampedTargetDuration(
                defaults.double(forKey: Self.targetDurationDefaultsKey)
            )
        }

        recalculateScrollSpeed()
    }

    private func recalculateScrollSpeed() {
        let travelDistance = Double(maximumOffset)

        switch paceMode {
        case .fixedSpeed:
            scrollSpeed = fixedScrollSpeed
        case .wordsPerMinute:
            guard travelDistance > 0, wordCount > 0 else {
                scrollSpeed = 0
                return
            }
            let readDuration = Double(wordCount) / wordsPerMinute * 60
            scrollSpeed = travelDistance / readDuration
        case .targetDuration:
            guard travelDistance > 0 else {
                scrollSpeed = 0
                return
            }
            scrollSpeed = travelDistance / targetDurationSeconds
        }
    }
}
