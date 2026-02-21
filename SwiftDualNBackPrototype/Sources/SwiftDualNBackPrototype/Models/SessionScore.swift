import Foundation

struct SessionScore: Codable, Identifiable {
    struct StreamCounts: Codable {
        let hits: Int
        let misses: Int
        let falsePositives: Int
    }

    let id: UUID
    let completedAt: Date
    let startN: Int
    let endN: Int
    let visualAccuracy: Double
    let audioAccuracy: Double
    let averageAccuracy: Double
    let visualCounts: StreamCounts
    let audioCounts: StreamCounts
}
