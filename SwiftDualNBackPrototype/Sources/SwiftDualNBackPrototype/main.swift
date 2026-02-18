import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class GameEngine: ObservableObject {
    @Published var nLevel: Int = 2
    @Published var trials: Int = 20
    @Published var stimulusMs: Int = 700
    @Published var cycleMs: Int = 1800

    @Published var isRunning = false
    @Published var trialIndex = -1
    @Published var currentPosition: Int? = nil
    @Published var statusText = "Press Start to begin"

    @Published var posHits = 0
    @Published var posMisses = 0
    @Published var posFalse = 0
    @Published var audHits = 0
    @Published var audMisses = 0
    @Published var audFalse = 0

    let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    private var history: [(position: Int, letter: Character)] = []
    private var responses: [(pos: Bool, aud: Bool)] = []
    private var awaitingResponseFor: Int? = nil

    private var cycleTimer: Timer?
    private var hideTimer: Timer?

    private let speech = AVSpeechSynthesizer()

    func start() {
        if isRunning { return }

        if nLevel < 1 || trials < nLevel + 2 {
            statusText = "Trials must be at least N + 2"
            return
        }
        if stimulusMs >= cycleMs {
            statusText = "Cycle ms must be greater than stimulus ms"
            return
        }

        isRunning = true
        trialIndex = -1
        history = []
        responses = []
        awaitingResponseFor = nil
        currentPosition = nil

        posHits = 0
        posMisses = 0
        posFalse = 0
        audHits = 0
        audMisses = 0
        audFalse = 0

        statusText = "Game running. F=position, J=audio"

        runTrial()
        cycleTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(cycleMs) / 1000.0, repeats: true) { [weak self] _ in
            self?.runTrial()
        }
    }

    func stop() {
        cycleTimer?.invalidate()
        hideTimer?.invalidate()
        cycleTimer = nil
        hideTimer = nil
        currentPosition = nil
        isRunning = false
    }

    func registerPositionKey() {
        guard isRunning, let idx = awaitingResponseFor else { return }
        responses[idx].pos = true
    }

    func registerAudioKey() {
        guard isRunning, let idx = awaitingResponseFor else { return }
        responses[idx].aud = true
    }

    private func runTrial() {
        guard isRunning else { return }

        if let prev = awaitingResponseFor {
            grade(trial: prev)
        }

        trialIndex += 1
        if trialIndex >= trials {
            finish()
            return
        }

        let position = Int.random(in: 0..<9)
        let letter = letters.randomElement() ?? "A"

        history.append((position, letter))
        responses.append((false, false))
        awaitingResponseFor = trialIndex

        currentPosition = position
        speak(letter: letter)

        statusText = "Trial \(trialIndex + 1)/\(trials)"

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(stimulusMs) / 1000.0, repeats: false) { [weak self] _ in
            self?.currentPosition = nil
        }
    }

    private func speak(letter: Character) {
        speech.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: String(letter).lowercased())
        u.rate = 0.53
        u.pitchMultiplier = 1.0
        if let preferred = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-US.Samantha") {
            u.voice = preferred
        } else {
            u.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        speech.speak(u)
    }

    private func grade(trial idx: Int) {
        if idx < nLevel { return }

        let curr = history[idx]
        let back = history[idx - nLevel]
        let resp = responses[idx]

        let posTarget = curr.position == back.position
        let audTarget = curr.letter == back.letter

        if posTarget && resp.pos { posHits += 1 }
        else if posTarget && !resp.pos { posMisses += 1 }
        else if !posTarget && resp.pos { posFalse += 1 }

        if audTarget && resp.aud { audHits += 1 }
        else if audTarget && !resp.aud { audMisses += 1 }
        else if !audTarget && resp.aud { audFalse += 1 }
    }

    private func finish() {
        if let final = awaitingResponseFor { grade(trial: final) }
        awaitingResponseFor = nil
        stop()
        let posScore = posHits - posFalse
        let audScore = audHits - audFalse
        statusText = "Finished. Position score: \(posScore), Audio score: \(audScore), Combined: \(posScore + audScore)"
    }
}

struct ContentView: View {
    @StateObject private var game = GameEngine()

    var body: some View {
        VStack(spacing: 14) {
            Text("Dual N-Back (Swift Prototype)")
                .font(.title2.bold())

            Text("F = position match | J = spoken-letter match")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                Stepper("N: \(game.nLevel)", value: $game.nLevel, in: 1...5)
                Stepper("Trials: \(game.trials)", value: $game.trials, in: 8...120)
            }

            HStack(spacing: 18) {
                Stepper("Stimulus ms: \(game.stimulusMs)", value: $game.stimulusMs, in: 300...2000, step: 50)
                Stepper("Cycle ms: \(game.cycleMs)", value: $game.cycleMs, in: 800...3000, step: 50)
            }

            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { col in
                            let idx = row * 3 + col
                            RoundedRectangle(cornerRadius: 10)
                                .fill(game.currentPosition == idx ? Color.orange : Color.gray.opacity(0.28))
                                .frame(width: 96, height: 96)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.6), lineWidth: 1.2)
                                )
                        }
                    }
                }
            }
            .padding(.vertical, 6)

            HStack(spacing: 12) {
                Button(game.isRunning ? "Running" : "Start") {
                    game.start()
                }
                .disabled(game.isRunning)

                Button("Stop") {
                    game.stop()
                }
                .disabled(!game.isRunning)
            }

            Text(game.statusText)
                .font(.callout)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)

            VStack(alignment: .leading, spacing: 4) {
                Text("Position H:\(game.posHits) M:\(game.posMisses) FA:\(game.posFalse)")
                Text("Audio    H:\(game.audHits) M:\(game.audMisses) FA:\(game.audFalse)")
            }
            .font(.system(.body, design: .monospaced))

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 760)
        .background(KeyCaptureView(
            onF: { game.registerPositionKey() },
            onJ: { game.registerAudioKey() }
        ))
    }
}

struct KeyCaptureView: NSViewRepresentable {
    let onF: () -> Void
    let onJ: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.start(onF: onF, onJ: onJ)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var monitor: Any?

        func start(onF: @escaping () -> Void, onJ: @escaping () -> Void) {
            stop()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                    return event
                }
                if chars == "f" {
                    onF()
                    return nil
                }
                if chars == "j" {
                    onJ()
                    return nil
                }
                return event
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        deinit {
            stop()
        }
    }
}

@main
struct DualNBackPrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
