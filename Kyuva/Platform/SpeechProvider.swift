import Speech
import AVFoundation

/// Platform-specific speech recognition provider
protocol SpeechProvider {
    var isAvailable: Bool { get }
    func requestAuthorization(completion: @escaping (Bool) -> Void)
    func startListening(onResult: @escaping ([String]) -> Void) throws
    func stopListening()
}

/// macOS implementation using Apple Speech framework
class AppleSpeechProvider: SpeechProvider {
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }
    
    init(locale: Locale = Locale(identifier: "en-US")) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    func startListening(onResult: @escaping ([String]) -> Void) throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechProviderError.unavailable
        }
        
        stopListening()
        
        // Note: macOS doesn't use AVAudioSession like iOS
        // Audio input is configured directly via AVAudioEngine
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechProviderError.requestFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let words = result.bestTranscription.formattedString
                    .lowercased()
                    .components(separatedBy: .alphanumerics.inverted)
                    .filter { !$0.isEmpty }
                onResult(words)
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

enum SpeechProviderError: Error {
    case unavailable
    case requestFailed
    case audioFailed
}
