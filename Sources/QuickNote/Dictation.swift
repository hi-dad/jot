import AVFoundation
import Speech

/// Live speech-to-text from the microphone using Apple's Speech framework.
final class Dictation: ObservableObject {
    @Published private(set) var isListening = false

    /// Called on the main actor with the full transcript so far, each time it changes.
    var onTranscript: (@MainActor (String) -> Void)?
    var onError: (@MainActor (String) -> Void)?

    private let recognizer = SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var wantsToListen = false
    private var session = 0

    func toggle() {
        wantsToListen ? stop() : start()
    }

    func start() {
        guard !wantsToListen else { return }
        wantsToListen = true
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else {
                    self.fail("Speech recognition is turned off for Jot. Turn it on in System Settings → Privacy & Security → Speech Recognition.")
                    return
                }
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    Task { @MainActor in
                        guard granted else {
                            self.fail("Microphone access is turned off for Jot. Turn it on in System Settings → Privacy & Security → Microphone.")
                            return
                        }
                        self.begin()
                    }
                }
            }
        }
    }

    func stop() {
        wantsToListen = false
        teardown()
    }

    private func begin() {
        // The panel may have been closed while a permission prompt was up.
        guard wantsToListen else { return }
        guard let recognizer, recognizer.isAvailable else {
            fail("Speech recognition isn't available right now.")
            return
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            fail("No microphone found.")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            fail("Couldn't start the microphone: \(error.localizedDescription)")
            return
        }

        session += 1
        let mySession = session
        self.request = request
        isListening = true
        task = recognizer.recognitionTask(with: request) { result, error in
            Task { @MainActor in
                // Ignore results that arrive after this session was stopped.
                guard mySession == self.session, self.isListening else { return }
                if let result {
                    self.onTranscript?(result.bestTranscription.formattedString)
                }
                if error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }

    private func teardown() {
        guard isListening else { return }
        isListening = false
        session += 1
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    private func fail(_ message: String) {
        wantsToListen = false
        teardown()
        Task { @MainActor in self.onError?(message) }
    }
}
