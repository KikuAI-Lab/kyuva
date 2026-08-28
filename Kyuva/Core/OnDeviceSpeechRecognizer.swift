import AVFoundation
import Combine
import Foundation
import NaturalLanguage
import Speech

enum OnDeviceSpeechState: Equatable {
    case idle
    case requestingPermission
    case listening(localeIdentifier: String)
    case permissionDenied
    case unsupported(localeIdentifier: String)
    case failed

    var isListening: Bool {
        if case .listening = self { return true }
        return false
    }
}

/// Streams partial transcripts from Apple's local speech recognizer.
///
/// `requiresOnDeviceRecognition` is always enabled. If Apple does not provide
/// an on-device recognizer for the script language, this object reports that
/// state instead of falling back to network recognition.
@MainActor
final class OnDeviceSpeechRecognizer: ObservableObject {
    @Published private(set) var state: OnDeviceSpeechState = .idle
    @Published private(set) var latestTranscript = ""

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var restartTask: Task<Void, Never>?
    private var shouldListen = false
    private var hasInstalledInputTap = false
    private var generation = 0

    deinit {
        recognitionTask?.cancel()
        restartTask?.cancel()
        if hasInstalledInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        #endif
    }

    func start(scriptText: String) async {
        stop()
        state = .requestingPermission
        let startGeneration = generation

        let hasPermission = await requestPermissions(generation: startGeneration)
        guard generation == startGeneration else { return }
        guard hasPermission else {
            state = .permissionDenied
            return
        }

        let detectedLanguage = NLLanguageRecognizer.dominantLanguage(for: scriptText)?.rawValue
        let locale = Self.chooseRecognitionLocale(
            languageCode: detectedLanguage,
            supportedLocales: SFSpeechRecognizer.supportedLocales(),
            preferredLanguageIdentifiers: Locale.preferredLanguages
        )
        let localeIdentifier = locale?.identifier
            ?? detectedLanguage
            ?? Locale.current.identifier
        guard let locale,
              let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.supportsOnDeviceRecognition else {
            state = .unsupported(localeIdentifier: localeIdentifier)
            return
        }

        speechRecognizer = recognizer
        shouldListen = true
        startRecognitionSession(generation: startGeneration)
    }

    func stop() {
        shouldListen = false
        generation += 1
        restartTask?.cancel()
        restartTask = nil
        stopRecognitionSession()
        speechRecognizer = nil
        latestTranscript = ""
        state = .idle
    }

    nonisolated static func chooseRecognitionLocale(
        languageCode: String?,
        supportedLocales: Set<Locale>,
        preferredLanguageIdentifiers: [String]
    ) -> Locale? {
        guard !supportedLocales.isEmpty else { return nil }

        let preferred = preferredLanguageIdentifiers.map(Locale.init(identifier:))

        if let languageCode {
            if let preferredMatch = preferred.first(where: {
                $0.language.languageCode?.identifier == languageCode
                    && supportedLocales.contains($0)
            }) {
                return preferredMatch
            }

            if let languageMatch = supportedLocales
                .filter({ $0.language.languageCode?.identifier == languageCode })
                .sorted(by: { $0.identifier < $1.identifier })
                .first {
                return languageMatch
            }

            return nil
        }

        if let exactPreferred = preferred.first(where: supportedLocales.contains) {
            return exactPreferred
        }

        return supportedLocales.sorted(by: { $0.identifier < $1.identifier }).first
    }

    private func startRecognitionSession(generation expectedGeneration: Int) {
        guard shouldListen,
              generation == expectedGeneration,
              let speechRecognizer else { return }

        stopRecognitionSession()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = false
        recognitionRequest = request

        do {
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                shouldListen = false
                stopRecognitionSession()
                state = .failed
                return
            }

            inputNode.installTap(
                onBus: 0,
                bufferSize: 1_024,
                format: format
            ) { [weak request] buffer, _ in
                request?.append(buffer)
            }
            hasInstalledInputTap = true

            audioEngine.prepare()
            try audioEngine.start()
            latestTranscript = ""
            state = .listening(localeIdentifier: speechRecognizer.locale.identifier)

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self,
                          self.shouldListen,
                          self.generation == expectedGeneration else { return }

                    if let result {
                        self.latestTranscript = result.bestTranscription.formattedString
                    }

                    if result?.isFinal == true {
                        self.scheduleRestart(after: expectedGeneration)
                    } else if error != nil {
                        self.shouldListen = false
                        self.stopRecognitionSession()
                        self.state = .failed
                    }
                }
            }
        } catch {
            shouldListen = false
            stopRecognitionSession()
            state = .failed
        }
    }

    private func scheduleRestart(after expectedGeneration: Int) {
        stopRecognitionSession()
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.startRecognitionSession(generation: expectedGeneration)
        }
    }

    private func stopRecognitionSession() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        if hasInstalledInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledInputTap = false
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        #endif
    }

    private func requestPermissions(generation expectedGeneration: Int) async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard generation == expectedGeneration else { return false }
        guard speechAuthorized else { return false }

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
