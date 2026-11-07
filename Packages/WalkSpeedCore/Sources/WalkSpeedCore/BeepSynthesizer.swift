import Foundation

/// Generates the alert sounds as WAV data, so the app ships no audio files.
///
/// Each ``AlertLevel`` has its own pattern. The further over the limit you
/// are, the more beeps there are and the higher they're pitched, so the
/// sound tells you how much to slow down without looking at the phone.
public enum BeepSynthesizer {
    /// Samples per second of the generated audio.
    public static let sampleRate = 44_100

    /// How long each beep lasts, in seconds.
    public static let beepDuration: TimeInterval = 0.15
    /// The silence between beeps, in seconds.
    public static let gapDuration: TimeInterval = 0.1
    /// Silence after the last beep, in seconds. It gives the audio session
    /// time to finish before it's deactivated, so the end isn't clipped.
    public static let tailDuration: TimeInterval = 0.05

    private static let attackDuration: TimeInterval = 0.005
    private static let releaseDuration: TimeInterval = 0.03
    private static let peakAmplitude = 0.9

    /// The pitch of a level's beeps, in hertz.
    public static func frequency(for level: AlertLevel) -> Double {
        switch level {
        case .gentle: 880 // A5
        case .firm: 1_046.5 // C6
        case .urgent: 1_318.5 // E6
        }
    }

    /// A level's beep pattern as 16-bit mono PCM samples.
    public static func samples(for level: AlertLevel) -> [Int16] {
        let beep = tone(frequency: frequency(for: level), frameCount: frameCount(for: beepDuration))
        let gap = [Int16](repeating: 0, count: frameCount(for: gapDuration))
        var output: [Int16] = []
        for index in 0..<level.beepCount {
            if index > 0 {
                output += gap
            }
            output += beep
        }
        output += [Int16](repeating: 0, count: frameCount(for: tailDuration))
        return output
    }

    /// A level's beep pattern as a complete WAV file.
    public static func wavData(for level: AlertLevel) -> Data {
        wavData(samples: samples(for: level))
    }

    /// Wraps 16-bit mono PCM samples in a WAV container.
    public static func wavData(samples: [Int16]) -> Data {
        let channelCount = 1
        let bytesPerSample = 2
        let dataSize = UInt32(samples.count * bytesPerSample)

        var data = Data(capacity: 44 + Int(dataSize))
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(36 + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendLittleEndian(UInt32(16)) // Size of the fmt chunk.
        data.appendLittleEndian(UInt16(1)) // Linear PCM.
        data.appendLittleEndian(UInt16(channelCount))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * channelCount * bytesPerSample)) // Byte rate.
        data.appendLittleEndian(UInt16(channelCount * bytesPerSample)) // Block alignment.
        data.appendLittleEndian(UInt16(bytesPerSample * 8)) // Bits per sample.
        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(dataSize)
        for sample in samples {
            data.appendLittleEndian(sample)
        }
        return data
    }

    static func frameCount(for duration: TimeInterval) -> Int {
        Int((duration * Double(sampleRate)).rounded())
    }

    /// A sine tone with a touch of its second harmonic, so it cuts through
    /// music. Short fades at each end prevent clicks.
    private static func tone(frequency: Double, frameCount: Int) -> [Int16] {
        let attackFrames = Self.frameCount(for: attackDuration)
        let releaseFrames = Self.frameCount(for: releaseDuration)
        return (0..<frameCount).map { frame in
            let time = Double(frame) / Double(sampleRate)
            let phase = 2 * Double.pi * frequency * time
            let wave = 0.8 * sin(phase) + 0.2 * sin(2 * phase)
            let envelope: Double
            if frame < attackFrames {
                envelope = Double(frame) / Double(attackFrames)
            } else if frame >= frameCount - releaseFrames {
                envelope = Double(frameCount - 1 - frame) / Double(releaseFrames)
            } else {
                envelope = 1
            }
            return Int16((wave * envelope * peakAmplitude * Double(Int16.max)).rounded())
        }
    }
}

private extension Data {
    mutating func appendLittleEndian<Value: FixedWidthInteger>(_ value: Value) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
