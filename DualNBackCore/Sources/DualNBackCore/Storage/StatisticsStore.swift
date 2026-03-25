import Foundation

public struct StatisticsStore {
    private let directoryName = "DualNBack"
    private let fileName = "score_history.json"
    private let fileManager = FileManager.default

    public init() {}

    public var fileURL: URL {
        let appSupportURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory

        return appSupportURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    public func load() throws -> [SessionScore] {
        let url = fileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([SessionScore].self, from: data)
    }

    public func save(_ sessions: [SessionScore]) throws {
        let url = fileURL
        let directoryURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sessions)
        try data.write(to: url, options: .atomic)
    }

    public func clear() throws {
        let url = fileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    // MARK: - Clipboard Transfer

    public func encodeForTransfer(_ sessions: [SessionScore]) -> Data? {
        let payload = StatsTransferPayload(version: 1, sessions: sessions)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(payload)
    }

    public func decodeFromTransfer(_ data: Data) -> [SessionScore]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(StatsTransferPayload.self, from: data) else {
            return nil
        }
        guard payload.version == 1 else { return nil }
        return payload.sessions
    }

    public struct MergeResult {
        public let merged: [SessionScore]
        public let newCount: Int
        public let duplicateCount: Int
    }

    public func merge(existing: [SessionScore], incoming: [SessionScore]) -> MergeResult {
        let existingIDs = Set(existing.map(\.id))
        let newSessions = incoming.filter { !existingIDs.contains($0.id) }
        let merged = (existing + newSessions).sorted { $0.completedAt < $1.completedAt }
        return MergeResult(
            merged: merged,
            newCount: newSessions.count,
            duplicateCount: incoming.count - newSessions.count
        )
    }
}
