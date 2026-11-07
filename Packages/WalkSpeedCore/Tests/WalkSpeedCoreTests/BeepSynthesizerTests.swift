import Foundation
import Testing
import WalkSpeedCore

@Suite("BeepSynthesizer")
struct BeepSynthesizerTests {
    @Test(arguments: AlertLevel.allCases)
    func playsOneBeepPerLevelStep(level: AlertLevel) {
        #expect(bursts(in: BeepSynthesizer.samples(for: level)) == level.beepCount)
    }

    @Test func higherLevelsArePitchedHigher() {
        let pitches = AlertLevel.allCases.map(BeepSynthesizer.frequency(for:))
        #expect(pitches == pitches.sorted())
        #expect(Set(pitches).count == pitches.count)
    }

    @Test func patternLengthMatchesTheTimings() {
        let samples = BeepSynthesizer.samples(for: .urgent)
        let seconds = 3 * BeepSynthesizer.beepDuration + 2 * BeepSynthesizer.gapDuration + BeepSynthesizer.tailDuration
        let expected = Int((seconds * Double(BeepSynthesizer.sampleRate)).rounded())
        #expect(abs(samples.count - expected) <= 3)
    }

    @Test(arguments: AlertLevel.allCases)
    func startsAndEndsSilentToAvoidClicks(level: AlertLevel) {
        let samples = BeepSynthesizer.samples(for: level)
        #expect(samples.first == 0)
        #expect(samples.last == 0)
    }

    @Test func isLoudButDoesNotClip() {
        let peak = BeepSynthesizer.samples(for: .gentle).map { abs(Int($0)) }.max() ?? 0
        #expect(peak > Int(Double(Int16.max) * 0.6))
        #expect(peak < Int(Int16.max))
    }

    @Test func writesAValidWAVHeader() throws {
        let samples: [Int16] = [0, 1_000, -1_000, 0]
        let data = BeepSynthesizer.wavData(samples: samples)
        #expect(data.count == 44 + samples.count * 2)
        #expect(ascii(data, 0..<4) == "RIFF")
        #expect(ascii(data, 8..<12) == "WAVE")
        #expect(ascii(data, 12..<16) == "fmt ")
        #expect(ascii(data, 36..<40) == "data")
        #expect(uint32(data, at: 4) == UInt32(data.count - 8))
        #expect(uint16(data, at: 20) == 1) // Linear PCM.
        #expect(uint16(data, at: 22) == 1) // Mono.
        #expect(uint32(data, at: 24) == UInt32(BeepSynthesizer.sampleRate))
        #expect(uint16(data, at: 34) == 16) // Bits per sample.
        #expect(uint32(data, at: 40) == UInt32(samples.count * 2))
        // Samples are little-endian: 1000 is 0x03E8.
        #expect(data[46] == 0xE8)
        #expect(data[47] == 0x03)
    }

    /// Counts the stretches of sound separated by at least 20 ms of silence.
    private func bursts(in samples: [Int16]) -> Int {
        let silenceFrames = BeepSynthesizer.sampleRate / 50
        var count = 0
        var quietRun = silenceFrames
        for sample in samples {
            if abs(Int(sample)) > 50 {
                if quietRun >= silenceFrames {
                    count += 1
                }
                quietRun = 0
            } else {
                quietRun += 1
            }
        }
        return count
    }

    private func ascii(_ data: Data, _ range: Range<Int>) -> String {
        String(decoding: data[range], as: UTF8.self)
    }

    private func uint16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func uint32(_ data: Data, at offset: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 | UInt32(data[offset + $1]) << (8 * $1) }
    }
}
