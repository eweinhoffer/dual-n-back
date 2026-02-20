import AppKit
import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class GameEngine: NSObject, ObservableObject {
    private let playableGridIndices = [0, 1, 2, 3, 5, 6, 7, 8]
    private let letterPool: [Character] = Array("BFHJKLQR")
    private lazy var positionAlternatives: [[Int]] = {
        (0..<playableGridIndices.count).map { index in
            (0..<playableGridIndices.count).filter { $0 != index }
        }
    }()
    private lazy var letterAlternatives: [Character: [Character]] = {
        Dictionary(uniqueKeysWithValues: letterPool.map { letter in
            (letter, letterPool.filter { $0 != letter })
        })
    }()

    private let stimulusOnSeconds: TimeInterval = 0.5
    private let cycleSeconds: TimeInterval = 3.0

    @Published var nLevel: Int = 2
    @Published var isRunning = false
    @Published var isPreparingStart = false
    @Published var trialIndex = -1
    @Published var currentPosition: Int? = nil // 0...7 ring index
    @Published var statusText = "Press Start to begin"
    @Published var didCompleteSession = false
    @Published var resultSummaryText = ""
    @Published var showResultPopup = false
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
    private let speechRate: Float = 0.47
    private lazy var preferredSpeechVoice: AVSpeechSynthesisVoice? = resolvePreferredVoice()

    override init() {
        super.init()
    }

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
        showResultPopup = false
        trialIndex = -1
        responses = []
        awaitingResponseFor = nil
        currentPosition = nil
        didCompleteSession = false
        resultSummaryText = ""

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
            DispatchQueue.main.async {
                self?.currentPosition = nil
            }
        }
    }

    private func beginCountdownAndStart() {
        clearCountdown()

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
                DispatchQueue.main.async {
                    self?.runTrial()
                }
            }
            self.cycleTimer?.tolerance = 0.02
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
                let choices = positionAlternatives[backPosition]
                positions[idx] = choices.randomElement() ?? ((backPosition + 1) % playableGridIndices.count)
            }

            if audShouldMatch {
                letters[idx] = backLetter
            } else {
                let choices = letterAlternatives[backLetter] ?? letterPool
                letters[idx] = choices.randomElement() ?? backLetter
            }
        }

        plannedTrials = zip(positions, letters).map { ($0.0, $0.1) }
        return true
    }

    private func speakCountdown(_ value: Int) {
        let utterance = AVSpeechUtterance(string: "\(value)")
        utterance.prefersAssistiveTechnologySettings = true
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.voice = preferredSpeechVoice
        speech.speak(utterance)
    }

    private func speak(letter: Character) {
        let utterance = AVSpeechUtterance(string: String(letter).lowercased())
        utterance.prefersAssistiveTechnologySettings = true
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.voice = preferredSpeechVoice
        speech.speak(utterance)
    }

    private func resolvePreferredVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        if #available(macOS 13.0, *) {
            if let premium = voices.first(where: { $0.quality == .premium }) {
                return premium
            }
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
            self?.visualButtonActive = false
        }
    }

    private func flashAudioButton() {
        audioButtonActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.audioButtonActive = false
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

        let resultText = String(
            format: "Finished. Visual %.1f%%, Audio %.1f%%, Avg %.1f%%. N: %d -> %d",
            posAccuracy,
            audAccuracy,
            averageAccuracy,
            oldN,
            nLevel
        )
        resultSummaryText = resultText
        statusText = resultText
        didCompleteSession = true
        showResultPopup = true
    }

    private func accuracyPercent(hits: Int, misses: Int, falsePositives: Int) -> Double {
        let denom = hits + misses + falsePositives
        guard denom > 0 else { return 0.0 }
        return (Double(hits) / Double(denom)) * 100.0
    }
}

struct ContentView: View {
    @StateObject private var game = GameEngine()
    @State private var showHelp = false
    @State private var showSettings = false
    @State private var visualHighlightColor: Color = .orange

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
                Button("Help") {
                    showHelp = true
                }
                Button("Settings") {
                    showSettings = true
                }
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
                                    .fill(game.currentDisplayIndex == displayIdx ? visualHighlightColor : Color.gray.opacity(0.28))
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

            if game.didCompleteSession && !game.isRunning && !game.isPreparingStart {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Visual TP:\(game.posHits)  Miss:\(game.posMisses)  FP:\(game.posFalse)")
                    Text("Audio  TP:\(game.audHits)  Miss:\(game.audMisses)  FP:\(game.audFalse)")
                }
                .font(.system(.body, design: .monospaced))
            }

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
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(visualHighlightColor: $visualHighlightColor)
        }
        .sheet(isPresented: $game.showResultPopup) {
            VStack(spacing: 18) {
                Text("Session Complete")
                    .font(.system(size: 36, weight: .bold))
                Text(game.resultSummaryText)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                Button("Close") {
                    game.showResultPopup = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .frame(minWidth: 640, minHeight: 320)
        }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How Dual N-Back Works")
                .font(.title.bold())
            Text("In each trial, one square in the 3x3 ring lights up and one spoken letter plays.")
            Text("Your task is to compare the current trial with the trial N steps earlier:")
            Text("• Press F for a visual match if the highlighted square is in the same position as N trials ago.")
            Text("• Press J for an auditory match if the spoken letter is the same as N trials ago.")
            Text("A trial can be visual-only, audio-only, both, or neither. Respond during the current 3-second cycle.")
            Text("Scoring uses hits, misses, and false positives. At the end of the session, the app adjusts N automatically based on your average accuracy.")
            Text("Timing:")
            Text("• Stimulus visible for 0.5 seconds")
            Text("• Gap for 2.5 seconds")
            Text("• Total cycle length: 3.0 seconds")
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 420)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var visualHighlightColor: Color
    private let presetColors: [Color] = [
        Color(red: 0.98, green: 0.62, blue: 0.33), // warm peach
        Color(red: 0.37, green: 0.70, blue: 0.94), // soft sky
        Color(red: 0.42, green: 0.78, blue: 0.61), // mint
        Color(red: 0.96, green: 0.78, blue: 0.42), // honey
        Color(red: 0.79, green: 0.64, blue: 0.96), // lavender
        Color(red: 0.95, green: 0.49, blue: 0.57), // coral rose
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title.bold())
            Text("Visual stimulus color")
                .font(.headline)
            Text("Quick presets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Array(presetColors.enumerated()), id: \.offset) { _, color in
                    Button {
                        visualHighlightColor = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            ColorPicker("Choose highlight color", selection: $visualHighlightColor, supportsOpacity: false)
            RoundedRectangle(cornerRadius: 10)
                .fill(visualHighlightColor)
                .frame(width: 120, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 260)
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
