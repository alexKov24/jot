import AVFoundation
import Speech

/// Live on-device speech-to-text from the mic, via SpeechAnalyzer.
@MainActor @Observable
final class Dictation {
    private(set) var isRecording = false
    /// Why dictation can't run, or what it's waiting on. Shown in the caption row.
    private(set) var message: String?

    private var task: Task<Void, Never>?
    private var engine: AVAudioEngine?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzer: SpeechAnalyzer?

    /// Starts or stops. `onText` gets everything heard so far, each time it changes.
    func toggle(onText: @escaping (String) -> Void) {
        if isRecording { return stop() }
        isRecording = true
        message = nil
        task = Task { await run(onText: onText) }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        task?.cancel()
        task = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        input?.finish()
        input = nil
        if let analyzer { Task { await analyzer.cancelAndFinishNow() } }
        analyzer = nil
    }

    private func fail(_ reason: String) {
        stop()
        message = reason
    }

    private func run(onText: @escaping (String) -> Void) async {
        // The first-time system prompts take focus, which closes the capture panel.
        guard await Self.micAllowed(), await Self.speechAllowed() else {
            return fail("Allow Microphone and Speech Recognition for Jot in System Settings › Privacy")
        }
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current)
        else { return fail("Speech-to-text isn't available for this language") }
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                message = "Downloading the speech model…"
                try await request.downloadAndInstall()
                message = nil
            }
            guard !Task.isCancelled else { return }
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                return fail("Speech-to-text isn't available")
            }
            let (stream, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            let engine = AVAudioEngine()
            self.input = input
            self.analyzer = analyzer
            self.engine = engine
            guard Self.tap(engine.inputNode, converting: format, into: input) else {
                return fail("No microphone found")
            }
            engine.prepare()
            try engine.start()
            try await analyzer.start(inputSequence: stream)

            var heard = ""
            for try await result in transcriber.results {
                let words = String(result.text.characters)
                let text = Self.join(heard, words)
                if result.isFinal { heard = text }
                onText(String(text.drop(while: \.isWhitespace)))
            }
        } catch {
            if !Task.isCancelled { fail(error.localizedDescription) }
        }
    }

    private static func join(_ a: String, _ b: String) -> String {
        a.isEmpty || a.last?.isWhitespace == true || b.first?.isWhitespace == true ? a + b : a + " " + b
    }

    nonisolated private static func micAllowed() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    nonisolated private static func speechAllowed() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { done in
                SFSpeechRecognizer.requestAuthorization { _ in done.resume() }
            }
        }
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// Feeds mic buffers, converted to the analyzer's format, into `input`. Runs on the audio thread.
    nonisolated private static func tap(_ node: AVAudioInputNode, converting format: AVAudioFormat, into input: AsyncStream<AnalyzerInput>.Continuation) -> Bool {
        let micFormat = node.outputFormat(forBus: 0)
        guard micFormat.sampleRate > 0, let converter = AVAudioConverter(from: micFormat, to: format) else { return false }
        node.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { buffer, _ in
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / micFormat.sampleRate) + 1
            guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
            // The converter calls back synchronously, once per output buffer.
            nonisolated(unsafe) let buffer = buffer
            nonisolated(unsafe) var fed = false
            converter.convert(to: out, error: nil) { _, status in
                if fed {
                    status.pointee = .noDataNow
                    return nil
                }
                fed = true
                status.pointee = .haveData
                return buffer
            }
            if out.frameLength > 0 { input.yield(AnalyzerInput(buffer: out)) }
        }
        return true
    }
}
