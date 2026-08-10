import AVFoundation
import Foundation
import SwiftUI

@MainActor
public final class GameEngine: NSObject, ObservableObject, AVAudioPlayerDelegate {
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

    private let stimulusOnDuration = Duration.milliseconds(500)
    private let cycleDuration = Duration.seconds(3)
    private let countdownStartDelay = Duration.milliseconds(3_500)
    // Longer routes can still have a previously queued countdown sound in
    // flight when the next one must be scheduled. AirPlay is intentionally
    // rejected; common speaker, wired, and Bluetooth routes remain supported.
    private let maximumUsableOutputLatency: TimeInterval = 0.350

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

    private var timelineTask: Task<Void, Never>?
    private var stimulusHideTask: Task<Void, Never>?
    private var visualButtonFeedbackTask: Task<Void, Never>?
    private var audioButtonFeedbackTask: Task<Void, Never>?

    private let speech = AVSpeechSynthesizer()
    private var speechPlayers: [String: AVAudioPlayer] = [:]
    private var activeSpeechPlayers: Set<AVAudioPlayer> = []
    #if os(macOS)
    private lazy var audioLatencyProbeEngine = AVAudioEngine()
    #endif
    private let speechRate: Float = 0.47
    private lazy var preferredSpeechVoice: AVSpeechSynthesisVoice? = resolvePreferredVoice()
    private let historyStore = StatisticsStore()
    private static let speechVoiceDefaultsKey = "speechVoice"
    public override init() {
        super.init()
        if let storedVoice = UserDefaults.standard.string(forKey: Self.speechVoiceDefaultsKey),
           let voice = SpeechVoice(rawValue: storedVoice) {
            speechVoice = voice
        }
        #if os(iOS)
        configureAudioSession(activate: false)
        #endif
        preloadBundledSpeech()
        loadHistory()
    }

    deinit {
        #if os(iOS)
        if let audioSessionInterruptionObserver {
            NotificationCenter.default.removeObserver(audioSessionInterruptionObserver)
        }
        if let audioRouteChangeObserver {
            NotificationCenter.default.removeObserver(audioRouteChangeObserver)
        }
        #endif
    }

    #if os(iOS)
    private var audioSessionConfigured = false
    private var audioSessionActive = false
    private var audioSessionInterruptionObserver: NSObjectProtocol?
    private var audioRouteChangeObserver: NSObjectProtocol?

    private func configureAudioSession(activate: Bool) {
        if audioSessionInterruptionObserver == nil {
            audioSessionInterruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
                Task { @MainActor [weak self] in
                    if type == .began {
                        self?.audioSessionActive = false
                        self?.stopForTimingSafety(
                            message: "Session stopped because audio was interrupted."
                        )
                    }
                }
            }
        }
        if audioRouteChangeObserver == nil {
            audioRouteChangeObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                if let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                   let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                   reason == .categoryChange {
                    // Ignore the category change performed by this engine.
                    return
                }
                Task { @MainActor [weak self] in
                    self?.stopForTimingSafety(
                        message: "Session stopped because the audio output changed. Start again to resync."
                    )
                }
            }
        }

        let session = AVAudioSession.sharedInstance()
        if !audioSessionConfigured {
            do {
                try session.setCategory(.playback, mode: .default, options: [.duckOthers])
                try? session.setPreferredIOBufferDuration(0.005)
                audioSessionConfigured = true
            } catch {
                // Non-fatal. Retry when the user next starts or previews audio.
                return
            }
        }

        guard activate, !audioSessionActive else { return }
        do {
            try session.setActive(true)
            audioSessionActive = true
        } catch {
            // Non-fatal: the bundled player can still report whether playback starts.
        }
    }

    private func deactivateAudioSession() {
        guard audioSessionActive else { return }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
        audioSessionActive = false
    }

    /// A backgrounded game cannot keep visual and auditory stimuli aligned.
    /// Stop it instead of silently grading an invalid session.
    public func handleAppBecameInactive() {
        stopForTimingSafety(message: "Session stopped when the app became inactive.")
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
        configureAudioSession(activate: true)
        #endif

        guard currentOutputLatency <= maximumUsableOutputLatency else {
            statusText = "This audio output is too delayed for accurate training. Use built-in speakers or wired headphones."
            #if os(iOS)
            deactivateAudioSession()
            #endif
            return
        }
        prepareBundledSpeech(voice: speechVoice)

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
        timelineTask?.cancel()
        stimulusHideTask?.cancel()
        visualButtonFeedbackTask?.cancel()
        audioButtonFeedbackTask?.cancel()
        activeSpeechPlayers.forEach { $0.stop() }
        activeSpeechPlayers.removeAll(keepingCapacity: true)
        speech.stopSpeaking(at: .immediate)
        timelineTask = nil
        stimulusHideTask = nil
        visualButtonFeedbackTask = nil
        audioButtonFeedbackTask = nil
        currentPosition = nil
        awaitingResponseFor = nil
        visualButtonActive = false
        audioButtonActive = false
        isRunning = false
        isPreparingStart = false
        countdownValue = nil
        #if os(iOS)
        deactivateAudioSession()
        #endif
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

    private func presentNextTrial() {
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

        statusText = "Trial \(trialIndex + 1)/\(totalTrials) | N=\(nLevel)"

        scheduleStimulusHide(forTrial: trialIndex)
    }

    private func beginCountdownAndStart() {
        timelineTask?.cancel()
        timelineTask = Task { @MainActor [weak self] in
            await self?.runTimeline()
        }
    }

    /// Uses absolute monotonic deadlines, so a late callback does not add drift
    /// to every later trial. Main-queue tasks also continue during UI tracking,
    /// unlike a default-mode run-loop Timer.
    private func runTimeline() async {
        let clock = ContinuousClock()
        let firstAudioAdvance = audioSchedulingAdvance()
        guard firstAudioAdvance <= maximumUsableOutputLatency
                + BundledSpeechTiming.deviceScheduleLeadSeconds
                + BundledSpeechTiming.spokenLeadSeconds else {
            stopForExcessiveOutputLatency()
            return
        }
        let countdownAnchor = clock.now.advanced(
            by: .seconds(firstAudioAdvance + BundledSpeechTiming.schedulingMarginSeconds)
        )

        for (offset, value) in [3, 2, 1].enumerated() {
            let presentationDeadline = countdownAnchor.advanced(by: .seconds(offset))
            guard await scheduleAudio(
                assetName: "countdown_\(value)",
                fallbackText: "\(value)",
                for: presentationDeadline,
                clock: clock
            ), isPreparingStart else { return }
            let visualDeadline = presentationDeadline.advanced(
                by: .seconds(-BundledSpeechTiming.visualCommitLeadSeconds)
            )
            guard await sleep(until: visualDeadline, clock: clock), isPreparingStart else { return }
            statusText = "Starting in \(value)..."
            countdownValue = value
        }

        var nextPresentationDeadline = countdownAnchor.advanced(by: countdownStartDelay)
        var isFirstTrial = true

        while (isPreparingStart || isRunning) && !Task.isCancelled {
            let nextIndex = trialIndex + 1
            if nextIndex < totalTrials {
                let advance = audioSchedulingAdvance()
                guard advance <= maximumUsableOutputLatency
                        + BundledSpeechTiming.deviceScheduleLeadSeconds
                        + BundledSpeechTiming.spokenLeadSeconds else {
                    stopForExcessiveOutputLatency()
                    return
                }

                let earliestSafeTarget = clock.now.advanced(
                    by: .seconds(advance + BundledSpeechTiming.schedulingMarginSeconds)
                )
                if earliestSafeTarget > nextPresentationDeadline {
                    // Rebase after a long system stall instead of presenting a
                    // late sound or bursting two trials close together.
                    nextPresentationDeadline = earliestSafeTarget
                }

                let trial = plannedTrials[nextIndex]
                let letterName = String(trial.letter).lowercased()
                guard await scheduleAudio(
                    assetName: "letter_\(letterName)",
                    fallbackText: letterName,
                    for: nextPresentationDeadline,
                    clock: clock
                ) else { return }

                let visualDeadline = nextPresentationDeadline.advanced(
                    by: .seconds(-BundledSpeechTiming.visualCommitLeadSeconds)
                )
                guard await sleep(until: visualDeadline, clock: clock) else { return }

                if isFirstTrial {
                    countdownValue = nil
                    isPreparingStart = false
                    isRunning = true
                    statusText = "Game running."
                    isFirstTrial = false
                }
                guard isRunning else { return }
                presentNextTrial()
            } else {
                guard await sleep(until: nextPresentationDeadline, clock: clock) else { return }
                presentNextTrial()
                return
            }

            guard isRunning && !Task.isCancelled else { return }
            nextPresentationDeadline = nextPresentationDeadline.advanced(by: cycleDuration)
        }
    }

    private func scheduleAudio(
        assetName: String,
        fallbackText: String,
        for presentationDeadline: ContinuousClock.Instant,
        clock: ContinuousClock
    ) async -> Bool {
        let advance = audioSchedulingAdvance()
        guard advance <= maximumUsableOutputLatency
                + BundledSpeechTiming.deviceScheduleLeadSeconds
                + BundledSpeechTiming.spokenLeadSeconds else {
            stopForExcessiveOutputLatency()
            return false
        }
        let audioDeadline = presentationDeadline.advanced(by: .seconds(-advance))
        guard await sleep(until: audioDeadline, clock: clock) else { return false }
        playBundledSpeech(assetName: assetName, fallbackText: fallbackText)
        return true
    }

    private func audioSchedulingAdvance() -> TimeInterval {
        currentOutputLatency
            + BundledSpeechTiming.deviceScheduleLeadSeconds
            + BundledSpeechTiming.spokenLeadSeconds
    }

    private var currentOutputLatency: TimeInterval {
        #if os(iOS)
        max(0, AVAudioSession.sharedInstance().outputLatency)
        #else
        max(0, audioLatencyProbeEngine.outputNode.presentationLatency)
        #endif
    }

    private func stopForExcessiveOutputLatency() {
        stop()
        statusText = "Session stopped because this audio output became too delayed. Use built-in speakers or wired headphones."
    }

    private func sleep(until deadline: ContinuousClock.Instant, clock: ContinuousClock) async -> Bool {
        do {
            try await clock.sleep(until: deadline, tolerance: .milliseconds(2))
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private func scheduleStimulusHide(forTrial presentedTrialIndex: Int) {
        stimulusHideTask?.cancel()
        let hideDelay = stimulusOnDuration
            + .seconds(BundledSpeechTiming.visualCommitLeadSeconds)
        stimulusHideTask = Task { @MainActor [weak self, hideDelay] in
            do {
                try await ContinuousClock().sleep(for: hideDelay, tolerance: .milliseconds(2))
            } catch {
                return
            }
            guard let self, self.trialIndex == presentedTrialIndex else { return }
            self.currentPosition = nil
        }
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
        timelineTask?.cancel()
        stimulusHideTask?.cancel()
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

    public func previewSpeechVoice() {
        guard !isRunning && !isPreparingStart else { return }
        #if os(iOS)
        configureAudioSession(activate: true)
        #endif
        playBundledSpeech(assetName: "countdown_3", fallbackText: "3")
    }

    private func playBundledSpeech(assetName: String, fallbackText: String) {
        speech.stopSpeaking(at: .immediate)

        let key = speechPlayerKey(voice: speechVoice, assetName: assetName)
        guard let player = speechPlayers[key] ?? loadSpeechPlayer(
            voice: speechVoice,
            assetName: assetName
        ) else {
            speakString(fallbackText)
            return
        }

        let calibratedOffset = BundledSpeechTiming.startOffset(
            voice: speechVoice,
            assetName: assetName
        )
        if activeSpeechPlayers.remove(player) != nil {
            player.stop()
            player.prepareToPlay()
        }
        player.currentTime = min(calibratedOffset, max(0, player.duration - 0.05))
        activeSpeechPlayers.insert(player)
        let presentationTime = player.deviceCurrentTime + BundledSpeechTiming.deviceScheduleLeadSeconds
        if !player.play(atTime: presentationTime) {
            activeSpeechPlayers.remove(player)
            speakString(fallbackText)
        }
    }

    private func preloadBundledSpeech() {
        assert(
            BundledSpeechTiming.calibratedClipCount
                == SpeechVoice.allCases.count * BundledSpeechTiming.assetNames.count,
            "Every bundled speech clip needs an onset calibration."
        )
        for voice in SpeechVoice.allCases {
            prepareBundledSpeech(voice: voice)
        }
    }

    private func prepareBundledSpeech(voice: SpeechVoice) {
        for assetName in BundledSpeechTiming.assetNames {
            loadSpeechPlayer(voice: voice, assetName: assetName)?.prepareToPlay()
        }
    }

    private func loadSpeechPlayer(voice: SpeechVoice, assetName: String) -> AVAudioPlayer? {
        let key = speechPlayerKey(voice: voice, assetName: assetName)
        if let existingPlayer = speechPlayers[key] {
            return existingPlayer
        }

        guard let url = BundledSpeechTiming.resourceURL(voice: voice, assetName: assetName),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return nil
        }

        player.prepareToPlay()
        player.delegate = self
        speechPlayers[key] = player
        return player
    }

    nonisolated public func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.activeSpeechPlayers.remove(player) != nil else { return }
            #if os(iOS)
            if self.activeSpeechPlayers.isEmpty && !self.isRunning && !self.isPreparingStart {
                self.deactivateAudioSession()
            }
            #endif
        }
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
        visualButtonFeedbackTask?.cancel()
        visualButtonActive = true
        visualButtonFeedbackTask = Task { @MainActor [weak self] in
            try? await ContinuousClock().sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            self?.visualButtonActive = false
        }
    }

    private func flashAudioButton() {
        audioButtonFeedbackTask?.cancel()
        audioButtonActive = true
        audioButtonFeedbackTask = Task { @MainActor [weak self] in
            try? await ContinuousClock().sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            self?.audioButtonActive = false
        }
    }

    private func stopForTimingSafety(message: String) {
        guard isRunning || isPreparingStart else { return }
        stop()
        statusText = message
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
