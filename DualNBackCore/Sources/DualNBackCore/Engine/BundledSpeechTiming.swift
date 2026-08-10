import Foundation

/// Playback calibration for the bundled speech recordings.
///
/// The source WAV files intentionally remain untouched. Each offset skips only
/// the recording-specific silence before the spoken sound, while retaining
/// roughly 20 ms of lead-in so consonant attacks are not clipped.
enum BundledSpeechTiming {
    static let assetNames = [
        "letter_b", "letter_f", "letter_h", "letter_j",
        "letter_k", "letter_l", "letter_q", "letter_r",
        "countdown_3", "countdown_2", "countdown_1",
    ]

    /// Apple documents 10 ms as a suitable future device-clock offset for
    /// synchronized AVAudioPlayer playback.
    static let deviceScheduleLeadSeconds: TimeInterval = 0.010

    /// The calibrated offsets retain about 20 ms before detectable speech so
    /// quiet consonant attacks remain intact.
    static let spokenLeadSeconds: TimeInterval = 0.020

    /// Publish SwiftUI state just before the shared audible target so the next
    /// display refresh presents the stimulus at approximately that target.
    static let visualCommitLeadSeconds: TimeInterval = 0.016

    /// Extra room used when establishing or rebasing the presentation clock.
    static let schedulingMarginSeconds: TimeInterval = 0.020

    private static let startOffsets: [String: TimeInterval] = [
        "cedar/countdown_1": 0.319,
        "cedar/countdown_2": 0.265,
        "cedar/countdown_3": 0.231,
        "cedar/letter_b": 0.017,
        "cedar/letter_f": 0.085,
        "cedar/letter_h": 0.116,
        "cedar/letter_j": 0.135,
        "cedar/letter_k": 0.042,
        "cedar/letter_l": 0.296,
        "cedar/letter_q": 0.352,
        "cedar/letter_r": 0.245,

        "coral/countdown_1": 0.170,
        "coral/countdown_2": 0.574,
        "coral/countdown_3": 0.225,
        "coral/letter_b": 0.116,
        "coral/letter_f": 1.050,
        "coral/letter_h": 0.063,
        "coral/letter_j": 0.099,
        "coral/letter_k": 0.000,
        "coral/letter_l": 0.089,
        "coral/letter_q": 0.248,
        "coral/letter_r": 0.214,

        "marin/countdown_1": 0.103,
        "marin/countdown_2": 0.408,
        "marin/countdown_3": 0.065,
        "marin/letter_b": 0.709,
        "marin/letter_f": 0.197,
        "marin/letter_h": 0.004,
        "marin/letter_j": 0.027,
        "marin/letter_k": 0.005,
        "marin/letter_l": 0.000,
        "marin/letter_q": 0.039,
        "marin/letter_r": 0.000,
    ]

    static func startOffset(voice: SpeechVoice, assetName: String) -> TimeInterval {
        startOffsets["\(voice.rawValue)/\(assetName)"] ?? 0
    }

    static func hasCalibration(voice: SpeechVoice, assetName: String) -> Bool {
        startOffsets["\(voice.rawValue)/\(assetName)"] != nil
    }

    static func resourceURL(voice: SpeechVoice, assetName: String) -> URL? {
        Bundle.module.url(
            forResource: assetName,
            withExtension: "wav",
            subdirectory: "Speech/\(voice.rawValue)"
        )
    }

    static var calibratedClipCount: Int {
        startOffsets.count
    }
}
