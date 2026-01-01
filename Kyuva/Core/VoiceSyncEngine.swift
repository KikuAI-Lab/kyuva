import Foundation
import Speech
import AVFoundation
import Combine

/// Voice-sync engine: matches spoken words to script tokens
class VoiceSyncEngine: ObservableObject {
    
    @Published var isListening: Bool = false
    @Published var recognizedText: String = ""
    @Published var confidence: Double = 0
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var scriptManager: ScriptManager?
    private var scrollController: ScrollController?
    
    // Anti-jitter settings
    private var lastSyncTime: Date = .distantPast
    private let minSyncInterval: TimeInterval = 0.3
    private let maxLinesJump = 3
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    func configure(scriptManager: ScriptManager, scrollController: ScrollController) {
        self.scriptManager = scriptManager
        self.scrollController = scrollController
    }
    
    // MARK: - Authorization
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    // MARK: - Start/Stop
    
    func start() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceSyncError.speechRecognizerUnavailable
        }
        
        // Cancel any existing task
        stop()
        
        // Note: macOS doesn't use AVAudioSession like iOS
        // Audio input is configured directly via AVAudioEngine
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceSyncError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // Privacy: local only
        
        // Start recognition
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.handleRecognitionResult(result)
            }
            
            if error != nil || result?.isFinal == true {
                self.stop()
            }
        }
        
        // Configure audio input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isListening = true
    }
    
    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
    }
    
    func resync() {
        // Reset to current scroll position
        recognizedText = ""
        lastSyncTime = .distantPast
    }
    
    // MARK: - Recognition Handling
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let transcript = result.bestTranscription.formattedString
        recognizedText = transcript
        
        // Extract last few words for matching
        let words = transcript
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .suffix(10)
        
        matchWordsToScript(Array(words))
    }
    
    private func matchWordsToScript(_ spokenWords: [String]) {
        guard let tokens = scriptManager?.tokens,
              let scrollController = scrollController else { return }
        
        // Anti-jitter: don't sync too frequently
        guard Date().timeIntervalSince(lastSyncTime) >= minSyncInterval else { return }
        
        let lineHeight: CGFloat = 28
        let currentLine = Int(scrollController.scrollOffset / lineHeight)
        let searchStart = max(0, currentLine - 1)
        let searchEnd = min(tokens.count, currentLine + 20)
        
        // Find best match in the search window
        var bestMatchLine = -1
        var bestMatchScore: Double = 0
        
        for i in searchStart..<searchEnd {
            guard i < tokens.count else { break }
            let token = tokens[i]
            
            // Check if any spoken word matches
            for word in spokenWords {
                if word == token.word {
                    // Calculate score (anchor words get higher weight)
                    var score = 0.7
                    if token.isAnchor { score += 0.2 }
                    if token.lineIndex > currentLine { score += 0.1 } // Prefer forward
                    
                    if score > bestMatchScore {
                        bestMatchScore = score
                        bestMatchLine = token.lineIndex
                    }
                }
            }
        }
        
        // Apply match if confidence is high enough
        if bestMatchLine > 0 && bestMatchScore > 0.6 {
            // Check max jump constraint
            let jump = bestMatchLine - currentLine
            if jump > 0 && jump <= maxLinesJump {
                confidence = bestMatchScore
                let lineHeight: CGFloat = 28
                scrollController.goToOffset(CGFloat(bestMatchLine) * lineHeight)
                lastSyncTime = Date()
            }
        }
    }
}

// MARK: - Errors

enum VoiceSyncError: Error, LocalizedError {
    case speechRecognizerUnavailable
    case requestCreationFailed
    case audioSessionFailed
    
    var errorDescription: String? {
        switch self {
        case .speechRecognizerUnavailable:
            return "Speech recognition is not available"
        case .requestCreationFailed:
            return "Failed to create recognition request"
        case .audioSessionFailed:
            return "Failed to configure audio session"
        }
    }
}
