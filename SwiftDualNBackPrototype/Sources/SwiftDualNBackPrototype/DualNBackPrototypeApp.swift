import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class GameEngine: ObservableObject {
    private let playableGridIndices = [0, 1, 2, 3, 5, 6, 7, 8]
    private let letterPool: [Character] = Array("BFJKLTV")

    private let stimulusOnSeconds: TimeInterval = 0.5
    private let cycleSeconds: TimeInterval = 3.0

    @Published var nLevel: Int = 2
    @Published var isRunning = false
    @Published var isPreparingStart = false
    @Published var trialIndex = -1
    @Published var currentPosition: Int? = nil // 0...7 ring index
    @Published var statusText = "Press Start to begin"
    @Published var visualButtonActive = false
    @Published var audioButtonActive = false

    @Published var posHits = 0
    @Published var posMisses = 0
    @Published var posFalse = 0
    @Published var audHits = 0
    @Published var audMisses = 0
    @Published var audFalse = 0

    private var plannedTrials: [(position: Int, letter: Character)] = []
    private var responses: [(pos: Bool, aud: Bool)] = []
    private var awaitingResponseFor: Int? = nil

    private var cycleTimer: Timer?
    private var hideTimer: Timer?
    private var countdownWorkItems: [DispatchWorkItem] = []

    private let speech = AVSpeechSynthesizer()

    var totalTrials: Int {
        20 + nLevel
    }

    var currentDisplayIndex: Int? {
        guard let currentPosition else { return nil }
        return playableGridIndices[currentPosition]
    }

    func start() {
        if isRunning || isPreparingStart { return }
        if nLevel < 1 { nLevel = 1 }

        guard buildTrialPlan() else {
            statusText = "Could not build valid trial plan for this N"
            return
        }

        isRunning = false
        isPreparingStart = true
        trialIndex = -1
        responses = []
        awaitingResponseFor = nil
        currentPosition = nil

        posHits = 0
        posMisses = 0
        posFalse = 0
        audHits = 0
        audMisses = 0
        audFalse = 0

        statusText = "Get ready..."
        beginCountdownAndStart()
    }

    func stop() {
        cycleTimer?.invalidate()
        hideTimer?.invalidate()
        clearCountdown()
        speech.stopSpeaking(at: .immediate)
        cycleTimer = nil
        hideTimer = nil
        currentPosition = nil
        isRunning = false
        isPreparingStart = false
    }

    func registerPositionAction() {
        guard isRunning, let idx = awaitingResponseFor else { return }
        flashVisualButton()
        responses[idx].pos = true
    }

    func registerAudioAction() {
        guard isRunning, let idx = awaitingResponseFor else { return }
        flashAudioButton()
        responses[idx].aud = true
    }

    private func runTrial() {
        guard isRunning else { return }

        if let prev = awaitingResponseFor {
            grade(trial: prev)
        }

        trialIndex += 1
        if trialIndex >= totalTrials {
            finish()
            return
        }

        let trial = plannedTrials[trialIndex]
        responses.append((false, false))
        awaitingResponseFor = trialIndex

        currentPosition = trial.position
        speak(letter: trial.letter)

        statusText = "Trial \(trialIndex + 1)/\(totalTrials) | N=\(nLevel)"

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: stimulusOnSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.currentPosition = nil
            }
        }
    }

    private func beginCountdownAndStart() {
        clearCountdown()

        // Warm speech engine slightly so first trial audio starts promptly.
        let warmup = AVSpeechUtterance(string: ".")
        warmup.volume = 0.0
        warmup.rate = 0.52
        speech.speak(warmup)
        speech.stopSpeaking(at: .immediate)

        let countdown = [3, 2, 1]
        for (offset, value) in countdown.enumerated() {
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.isPreparingStart else { return }
                self.statusText = "Starting in \(value)..."
                self.speakCountdown(value)
            }
            countdownWorkItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(offset), execute: item)
        }

        let startItem = DispatchWorkItem { [weak self] in
            guard let self, self.isPreparingStart else { return }
            self.isPreparingStart = false
            self.isRunning = true
            self.statusText = "Game running. Trial pacing is fixed at 3.0s (0.5s on, 2.5s gap)."
            self.runTrial()
            self.cycleTimer = Timer.scheduledTimer(withTimeInterval: self.cycleSeconds, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.runTrial()
                }
            }
        }
        countdownWorkItems.append(startItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: startItem)
    }

    private func clearCountdown() {
        countdownWorkItems.forEach { $0.cancel() }
        countdownWorkItems.removeAll()
    }

    private func buildTrialPlan() -> Bool {
        let trials = totalTrials
        if trials <= nLevel { return false }

        let opportunities = Array(nLevel..<trials) // Always 20 slots by design.
        if opportunities.count < 10 { return false }

        let bothCount = 2
        let visualOnlyCount = 4
        let audioOnlyCount = 4

        var shuffled = opportunities.shuffled()
        let bothTargets = Set(shuffled.prefix(bothCount))
        shuffled.removeFirst(bothCount)
        let visualOnlyTargets = Set(shuffled.prefix(visualOnlyCount))
        shuffled.removeFirst(visualOnlyCount)
        let audioOnlyTargets = Set(shuffled.prefix(audioOnlyCount))

        var positions: [Int] = Array(repeating: 0, count: trials)
        var letters: [Character] = Array(repeating: "B", count: trials)

        for idx in 0..<trials {
            if idx < nLevel {
                positions[idx] = Int.random(in: 0..<playableGridIndices.count)
                letters[idx] = letterPool.randomElement() ?? "B"
                continue
            }

            let backPosition = positions[idx - nLevel]
            let backLetter = letters[idx - nLevel]

            let posShouldMatch = visualOnlyTargets.contains(idx) || bothTargets.contains(idx)
            let audShouldMatch = audioOnlyTargets.contains(idx) || bothTargets.contains(idx)

            if posShouldMatch {
                positions[idx] = backPosition
            } else {
                let choices = (0..<playableGridIndices.count).filter { $0 != backPosition }
                positions[idx] = choices.randomElement() ?? ((backPosition + 1) % playableGridIndices.count)
            }

            if audShouldMatch {
                letters[idx] = backLetter
            } else {
                let choices = letterPool.filter { $0 != backLetter }
                letters[idx] = choices.randomElement() ?? backLetter
            }
        }

        plannedTrials = zip(positions, letters).map { ($0.0, $0.1) }
        return true
    }

    private func speakCountdown(_ value: Int) {
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "\(value)")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.voice = preferredVoice()
        speech.speak(utterance)
    }

    private func speak(letter: Character) {
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: String(letter).lowercased())
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.05
        utterance.voice = preferredVoice()
        speech.speak(utterance)
    }

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        if #available(macOS 13.0, *) {
            let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
            if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
                return enhanced
            }
        }
        if let ava = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Ava") {
            return ava
        }
        if let samantha = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-US.Samantha") {
            return samantha
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    private func flashVisualButton() {
        visualButtonActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            Task { @MainActor in
                self?.visualButtonActive = false
            }
        }
    }

    private func flashAudioButton() {
        audioButtonActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            Task { @MainActor in
                self?.audioButtonActive = false
            }
        }
    }

    private func grade(trial idx: Int) {
        guard idx >= nLevel else { return }

        let curr = plannedTrials[idx]
        let back = plannedTrials[idx - nLevel]
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
        if let final = awaitingResponseFor {
            grade(trial: final)
        }
        awaitingResponseFor = nil
        stop()

        let posAccuracy = accuracyPercent(hits: posHits, misses: posMisses, falsePositives: posFalse)
        let audAccuracy = accuracyPercent(hits: audHits, misses: audMisses, falsePositives: audFalse)
        let averageAccuracy = (posAccuracy + audAccuracy) / 2.0

        let oldN = nLevel
        if averageAccuracy >= 90.0 {
            nLevel += 1
        } else if averageAccuracy < 75.0 {
            nLevel = max(1, nLevel - 1)
        }

        statusText = String(
            format: "Finished. Visual %.1f%%, Audio %.1f%%, Avg %.1f%%. N: %d -> %d",
            posAccuracy,
            audAccuracy,
            averageAccuracy,
            oldN,
            nLevel
        )
    }

    private func accuracyPercent(hits: Int, misses: Int, falsePositives: Int) -> Double {
        let denom = hits + misses + falsePositives
        guard denom > 0 else { return 0.0 }
        return (Double(hits) / Double(denom)) * 100.0
    }
}

struct ContentView: View {
    @StateObject private var game = GameEngine()

    var body: some View {
        VStack(spacing: 14) {
            Text("Dual N-Back (Swift)")
                .font(.title2.bold())

            Text("F = visual match | J = auditory-letter match")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                Stepper("N: \(game.nLevel)", value: $game.nLevel, in: 1...8)
                Text("Trials this session: \(game.totalTrials)")
                    .font(.callout)
            }

            Text("Timing is fixed: 500ms stimulus + 2500ms gap (3s total pacing)")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { col in
                            let displayIdx = row * 3 + col
                            if displayIdx == 4 {
                                Color.clear
                                    .frame(width: 96, height: 96)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(game.currentDisplayIndex == displayIdx ? Color.orange : Color.gray.opacity(0.28))
                                    .frame(width: 96, height: 96)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.6), lineWidth: 1.2)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 6)

            HStack(spacing: 12) {
                Button(game.isRunning || game.isPreparingStart ? "Running" : "Start") {
                    game.start()
                }
                .disabled(game.isRunning || game.isPreparingStart)

                Button("Stop") {
                    game.stop()
                }
                .disabled(!game.isRunning && !game.isPreparingStart)
            }

            HStack(spacing: 12) {
                Button {
                    game.registerPositionAction()
                } label: {
                    Label("Visual Match (F)", systemImage: "square.grid.3x3.fill")
                        .frame(minWidth: 190)
                }
                .buttonStyle(.borderedProminent)
                .tint(game.visualButtonActive ? .orange : .accentColor)
                .disabled(!game.isRunning)

                Button {
                    game.registerAudioAction()
                } label: {
                    Label("Auditory Match (J)", systemImage: "speaker.wave.2.fill")
                        .frame(minWidth: 190)
                }
                .buttonStyle(.borderedProminent)
                .tint(game.audioButtonActive ? .orange : .accentColor)
                .disabled(!game.isRunning)
            }

            Text(game.statusText)
                .font(.callout)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 620)

            VStack(alignment: .leading, spacing: 4) {
                Text("Visual TP:\(game.posHits)  Miss:\(game.posMisses)  FP:\(game.posFalse)")
                Text("Audio  TP:\(game.audHits)  Miss:\(game.audMisses)  FP:\(game.audFalse)")
            }
            .font(.system(.body, design: .monospaced))

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(idealWidth: 760, idealHeight: 760)
        .background(
            KeyCaptureView(
                onF: { game.registerPositionAction() },
                onJ: { game.registerAudioAction() }
            )
        )
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

struct DualNBackPrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.automatic)
    }
}
