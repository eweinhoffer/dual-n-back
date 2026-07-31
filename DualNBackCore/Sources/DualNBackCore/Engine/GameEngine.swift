import AVFoundation
import Foundation
import SwiftUI

@MainActor
public final class GameEngine: NSObject, ObservableObject {
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
    private let countdownStartDelaySeconds: TimeInterval = 3.5

    @Published public var nLevel: Int = 2
    @Published public var isRunning = false
    @Published public var isPreparingStart = false
    @Published public var trialIndex = -1
    @Published public var currentPosition: Int? = nil
    @Published public var statusText = ""
    @Published public var didCompleteSession = false
    @Published public var resultSummaryText = ""
    @Published public var showResultPopup = false
    @Published public var visualButtonActive = false
    @Published public var audioButtonActive = false
    @Published public var countdownValue: Int? = nil
    @Published public var speechVoice: SpeechVoice = .marin {
        didSet {
            UserDefaults.standard.set(speechVoice.rawValue, forKey: Self.speechVoiceDefaultsKey)
        }
    }

    @Published public var posHits = 0
    @Published public var posMisses = 0
    @Published public var posFalse = 0
    @Published public var audHits = 0
    @Published public var audMisses = 0
    @Published public var audFalse = 0
    @Published public private(set) var statisticsHistory: [SessionScore] = []

    private var plannedTrials: [(position: Int, letter: Character)] = []
    private var responses: [(pos: Bool, aud: Bool)] = []
    private var awaitingResponseFor: Int? = nil

    private var cycleTimer: Timer?
    private var hideTimer: Timer?
    private var countdownWorkItems: [DispatchWorkItem] = []

    private let speech = AVSpeechSynthesizer()
    private var speechPlayers: [String: AVAudioPlayer] = [:]
    private var activeSpeechPlayer: AVAudioPlayer?
    private let speechRate: Float = 0.47
    private lazy var preferredSpeechVoice: AVSpeechSynthesisVoice? = resolvePreferredVoice()
    private let historyStore = StatisticsStore()
    private static let speechVoiceDefaultsKey = "speechVoice"
    private static let bundledSpeechAssetNames = [
        "letter_b", "letter_f", "letter_h", "letter_j",
        "letter_k", "letter_l", "letter_q", "letter_r",
        "countdown_3", "countdown_2", "countdown_1",
    ]

    public override init() {
        super.init()
        if let storedVoice = UserDefaults.standard.string(forKey: Self.speechVoiceDefaultsKey),
           let voice = SpeechVoice(rawValue: storedVoice) {
            speechVoice = voice
        }
        #if os(iOS)
        configureAudioSession()
        #endif
        preloadBundledSpeech()
        loadHistory()
    }

    #if os(iOS)
    private var audioSessionConfigured = false

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try? session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            // Non-fatal: speech may not play when the silent switch is on
        }
        guard !audioSessionConfigured else { return }
        audioSessionConfigured = true
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            if type == .ended {
                try? AVAudioSession.sharedInstance().setActive(true)
            }
        }
    }
    #endif

    public var totalTrials: Int {
        20 + nLevel
    }

    public var buttonsAvailable: Bool {
        isRunning && trialIndex >= nLevel
    }

    public var currentDisplayIndex: Int? {
        guard let currentPosition else { return nil }
        return playableGridIndices[currentPosition]
    }

    public func start() {
        if isRunning || isPreparingStart { return }
        nLevel = GameLimits.clampedNLevel(nLevel)

        #if os(iOS)
        configureAudioSession()
        #endif

        guard buildTrialPlan() else {
            statusText = "Could not build valid trial plan for this N"
            return
        }
        prepareSessionForStart()
        responses.reserveCapacity(totalTrials)

        statusText = "Get ready..."
        beginCountdownAndStart()
    }

    public func stop() {
        cycleTimer?.invalidate()
        hideTimer?.invalidate()
        clearCountdown()
        activeSpeechPlayer?.stop()
        activeSpeechPlayer = nil
        speech.stopSpeaking(at: .immediate)
        cycleTimer = nil
        hideTimer = nil
        currentPosition = nil
        awaitingResponseFor = nil
        visualButtonActive = false
        audioButtonActive = false
        isRunning = false
        isPreparingStart = false
        countdownValue = nil
    }

    public func registerPositionAction() {
        guard buttonsAvailable,
              let idx = awaitingResponseFor,
              responses.indices.contains(idx),
              !responses[idx].pos else { return }
        flashVisualButton()
        responses[idx].pos = true
    }

    public func registerAudioAction() {
        guard buttonsAvailable,
              let idx = awaitingResponseFor,
              responses.indices.contains(idx),
              !responses[idx].aud else { return }
        flashAudioButton()
        responses[idx].aud = true
    }

    // MARK: - Clipboard Transfer

    public enum PasteResult {
        case success(newCount: Int, duplicateCount: Int)
        case noData
        case invalidFormat
    }

    public func copyStatsToClipboard() -> Int {
        guard let data = historyStore.encodeForTransfer(statisticsHistory) else { return 0 }
        ClipboardHelper.copyToClipboard(data)
        return statisticsHistory.count
    }

    public func pasteStatsFromClipboard() -> PasteResult {
        guard let data = ClipboardHelper.readFromClipboard() else {
            return .noData
        }
        guard let incomingSessions = historyStore.decodeFromTransfer(data) else {
            return .invalidFormat
        }
        let result = historyStore.merge(existing: statisticsHistory, incoming: incomingSessions)
        statisticsHistory = result.merged
        if let lastSession = statisticsHistory.last {
            nLevel = GameLimits.clampedNLevel(lastSession.endN)
        }
        do {
            try historyStore.save(statisticsHistory)
        } catch {
            statusText = "Sessions merged but could not save. \(error.localizedDescription)"
        }
        return .success(newCount: result.newCount, duplicateCount: result.duplicateCount)
    }

    public func clearStatisticsHistory() {
        do {
            try historyStore.clear()
            statisticsHistory.removeAll()
            statusText = "Saved score history was erased."
        } catch {
            statusText = "Could not erase score history. \(error.localizedDescription)"
        }
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
            Task { @MainActor in self?.currentPosition = nil }
        }
    }

    private func beginCountdownAndStart() {
        clearCountdown()

        let countdown = [3, 2, 1]
        for (offset, value) in countdown.enumerated() {
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.isPreparingStart else { return }
                self.statusText = "Starting in \(value)..."
                self.countdownValue = value
                self.speakCountdown(value)
            }
            countdownWorkItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(offset), execute: item)
        }

        let startItem = DispatchWorkItem { [weak self] in
            guard let self, self.isPreparingStart else { return }
            self.countdownValue = nil
            self.isPreparingStart = false
            self.isRunning = true
            self.statusText = "Game running."
            self.runTrial()
            self.cycleTimer = Timer.scheduledTimer(withTimeInterval: self.cycleSeconds, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.runTrial() }
            }
            self.cycleTimer?.tolerance = 0.02
        }
        countdownWorkItems.append(startItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + countdownStartDelaySeconds, execute: startItem)
    }

    private func clearCountdown() {
        countdownWorkItems.forEach { $0.cancel() }
        countdownWorkItems.removeAll()
    }

    private func buildTrialPlan() -> Bool {
        let trials = totalTrials
        if trials <= nLevel { return false }

        let opportunities = Array(nLevel..<trials)
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

    private func prepareSessionForStart() {
        isRunning = false
        isPreparingStart = true
        showResultPopup = false
        trialIndex = -1
        responses.removeAll(keepingCapacity: true)
        awaitingResponseFor = nil
        currentPosition = nil
        didCompleteSession = false
        resultSummaryText = ""
        resetScoreCounters()
    }

    private func resetScoreCounters() {
        posHits = 0
        posMisses = 0
        posFalse = 0
        audHits = 0
        audMisses = 0
        audFalse = 0
    }

    private func speakCountdown(_ value: Int) {
        playBundledSpeech(assetName: "countdown_\(value)", fallbackText: "\(value)")
    }

    private func speak(letter: Character) {
        let letterName = String(letter).lowercased()
        playBundledSpeech(assetName: "letter_\(letterName)", fallbackText: letterName)
    }

    public func previewSpeechVoice() {
        guard !isRunning && !isPreparingStart else { return }
        playBundledSpeech(assetName: "countdown_3", fallbackText: "3")
    }

    private func playBundledSpeech(assetName: String, fallbackText: String) {
        let key = speechPlayerKey(voice: speechVoice, assetName: assetName)
        guard let player = speechPlayers[key] ?? loadSpeechPlayer(
            voice: speechVoice,
            assetName: assetName
        ) else {
            speakString(fallbackText)
            return
        }

        activeSpeechPlayer?.stop()
        speech.stopSpeaking(at: .immediate)
        player.currentTime = 0
        activeSpeechPlayer = player
        if !player.play() {
            speakString(fallbackText)
        }
    }

    private func preloadBundledSpeech() {
        for voice in SpeechVoice.allCases {
            for assetName in Self.bundledSpeechAssetNames {
                _ = loadSpeechPlayer(voice: voice, assetName: assetName)
            }
        }
    }

    private func loadSpeechPlayer(voice: SpeechVoice, assetName: String) -> AVAudioPlayer? {
        let key = speechPlayerKey(voice: voice, assetName: assetName)
        if let existingPlayer = speechPlayers[key] {
            return existingPlayer
        }

        guard let url = Bundle.module.url(
            forResource: assetName,
            withExtension: "wav",
            subdirectory: "Speech/\(voice.rawValue)"
        ), let player = try? AVAudioPlayer(contentsOf: url) else {
            return nil
        }

        player.prepareToPlay()
        speechPlayers[key] = player
        return player
    }

    private func speechPlayerKey(voice: SpeechVoice, assetName: String) -> String {
        "\(voice.rawValue)/\(assetName)"
    }

    private func speakString(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.prefersAssistiveTechnologySettings = true
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.voice = preferredSpeechVoice
        speech.speak(utterance)
    }

    private func resolvePreferredVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        #if os(macOS)
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
        #else
        if let premium = voices.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        if let ava = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Ava") {
            return ava
        }
        #endif
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
            nLevel = GameLimits.clampedNLevel(nLevel + 1)
        } else if averageAccuracy < 75.0 {
            nLevel = GameLimits.clampedNLevel(nLevel - 1)
        }

        let session = SessionScore(
            id: UUID(),
            completedAt: Date(),
            startN: oldN,
            endN: nLevel,
            visualAccuracy: posAccuracy,
            audioAccuracy: audAccuracy,
            averageAccuracy: averageAccuracy,
            visualCounts: .init(hits: posHits, misses: posMisses, falsePositives: posFalse),
            audioCounts: .init(hits: audHits, misses: audMisses, falsePositives: audFalse)
        )
        appendSessionToHistory(session)

        let resultText = String(
            format: "Finished. Visual %.1f%%, Audio %.1f%%, Avg %.1f%%. N: %d \u{2192} %d",
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

    private func appendSessionToHistory(_ session: SessionScore) {
        if let last = statisticsHistory.last, last.completedAt <= session.completedAt {
            statisticsHistory.append(session)
        } else if let insertionIndex = statisticsHistory.firstIndex(where: { $0.completedAt > session.completedAt }) {
            statisticsHistory.insert(session, at: insertionIndex)
        } else {
            statisticsHistory.append(session)
        }

        do {
            try historyStore.save(statisticsHistory)
        } catch {
            statusText = "Session finished, but score history could not be saved. \(error.localizedDescription)"
        }
    }

    private func loadHistory() {
        do {
            statisticsHistory = try historyStore.load().sorted { $0.completedAt < $1.completedAt }
        } catch {
            statisticsHistory = []
            statusText = "Could not load score history. Starting fresh."
        }
    }
}
