import Foundation

/// The speed over the course of a walk, averaged into short buckets for a
/// chart.
public struct SpeedTrace: Sendable {
    /// The average speed over one bucket.
    public struct Point: Codable, Equatable, Sendable {
        /// The middle of the bucket, in seconds since the walk started.
        public var offset: TimeInterval
        /// The average speed in metres per second.
        public var speed: Double

        public init(offset: TimeInterval, speed: Double) {
            self.offset = offset
            self.speed = speed
        }
    }

    public let startDate: Date
    /// How long each bucket lasts, in seconds.
    public let bucketDuration: TimeInterval
    /// The finished buckets, oldest first.
    public private(set) var points: [Point] = []

    private var bucketIndex: Int?
    private var bucketTotal = 0.0
    private var bucketCount = 0

    public init(startDate: Date, bucketDuration: TimeInterval = 5) {
        self.startDate = startDate
        self.bucketDuration = bucketDuration
    }

    /// Adds a speed. Unknown speeds are skipped and leave a gap. A speed
    /// older than the current bucket is ignored.
    public mutating func add(speed: Double?, at date: Date) {
        guard let speed else { return }
        let index = Int((date.timeIntervalSince(startDate) / bucketDuration).rounded(.down))
        guard index >= (bucketIndex ?? 0) else { return }
        if index != bucketIndex {
            closeBucket()
            bucketIndex = index
        }
        bucketTotal += speed
        bucketCount += 1
    }

    /// Closes the last bucket. Call it when the walk ends.
    public mutating func finish() {
        closeBucket()
        bucketIndex = nil
    }

    private mutating func closeBucket() {
        guard let bucketIndex, bucketCount > 0 else { return }
        let middle = (Double(bucketIndex) + 0.5) * bucketDuration
        points.append(Point(offset: middle, speed: bucketTotal / Double(bucketCount)))
        bucketTotal = 0
        bucketCount = 0
    }
}
