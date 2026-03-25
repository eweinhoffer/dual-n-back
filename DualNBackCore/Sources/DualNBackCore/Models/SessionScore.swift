import Foundation

public struct SessionScore: Codable, Identifiable {
    public struct StreamCounts: Codable {
        public let hits: Int
        public let misses: Int
        public let falsePositives: Int

        public init(hits: Int, misses: Int, falsePositives: Int) {
            self.hits = hits
            self.misses = misses
            self.falsePositives = falsePositives
        }
    }

    public let id: UUID
    public let completedAt: Date
    public let startN: Int
    public let endN: Int
    public let visualAccuracy: Double
    public let audioAccuracy: Double
    public let averageAccuracy: Double
    public let visualCounts: StreamCounts
    public let audioCounts: StreamCounts

    public init(
        id: UUID,
        completedAt: Date,
        startN: Int,
        endN: Int,
        visualAccuracy: Double,
        audioAccuracy: Double,
        averageAccuracy: Double,
        visualCounts: StreamCounts,
        audioCounts: StreamCounts
    ) {
        self.id = id
        self.completedAt = completedAt
        self.startN = startN
        self.endN = endN
        self.visualAccuracy = visualAccuracy
        self.audioAccuracy = audioAccuracy
        self.averageAccuracy = averageAccuracy
        self.visualCounts = visualCounts
        self.audioCounts = audioCounts
    }
}
