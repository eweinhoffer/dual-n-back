import AVFoundation
import XCTest
@testable import DualNBackCore

final class BundledSpeechTimingTests: XCTestCase {
    func testEveryBundledClipExistsAndHasAValidCalibration() throws {
        let expectedClipCount = SpeechVoice.allCases.count * BundledSpeechTiming.assetNames.count
        XCTAssertEqual(BundledSpeechTiming.calibratedClipCount, expectedClipCount)

        for voice in SpeechVoice.allCases {
            for assetName in BundledSpeechTiming.assetNames {
                XCTAssertTrue(
                    BundledSpeechTiming.hasCalibration(voice: voice, assetName: assetName),
                    "Missing timing calibration for \(voice.rawValue)/\(assetName)"
                )

                let url = try XCTUnwrap(
                    BundledSpeechTiming.resourceURL(voice: voice, assetName: assetName),
                    "Missing bundled speech file for \(voice.rawValue)/\(assetName)"
                )
                let player = try AVAudioPlayer(contentsOf: url)
                let offset = BundledSpeechTiming.startOffset(voice: voice, assetName: assetName)

                XCTAssertGreaterThanOrEqual(offset, 0)
                XCTAssertLessThan(
                    offset,
                    player.duration - 0.05,
                    "Timing offset skips the spoken clip for \(voice.rawValue)/\(assetName)"
                )

                let detectedOnset = try detectableSpeechOnset(in: url)
                let retainedLead = detectedOnset - offset
                XCTAssertGreaterThanOrEqual(
                    retainedLead,
                    0,
                    "Timing offset clips speech onset for \(voice.rawValue)/\(assetName)"
                )
                XCTAssertLessThanOrEqual(
                    retainedLead,
                    0.030,
                    "Too much uncalibrated lead-in remains for \(voice.rawValue)/\(assetName)"
                )
            }
        }
    }

    private func detectableSpeechOnset(in url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let capacity = AVAudioFrameCount(file.length)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)
        )
        try file.read(into: buffer)
        let channels = try XCTUnwrap(buffer.floatChannelData)
        let threshold = Float(pow(10.0, -30.0 / 20.0))

        for frame in 0..<Int(buffer.frameLength) {
            for channel in 0..<Int(format.channelCount) where abs(channels[channel][frame]) >= threshold {
                return Double(frame) / format.sampleRate
            }
        }

        XCTFail("No detectable speech found in \(url.lastPathComponent)")
        return 0
    }
}
