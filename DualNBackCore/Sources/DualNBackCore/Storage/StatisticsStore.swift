import Foundation

public struct StatisticsStore {
    private let directoryName = "DualNBack"
    private let fileName = "score_history.json"
    private let maximumTransferPayloadBytes = 1_000_000
    private let maximumTransferSessions = 10_000
    private let maximumReasonableCount = 10_000
    private let maximumStoredNLevel = 64
    private let fileManager = FileManager.default

    public init() {}

    public var fileURL: URL {
        let appSupportURL = (try? resolvedFileURL().deletingLastPathComponent().deletingLastPathComponent())
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return appSupportURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    private func resolvedFileURL() throws -> URL {
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return appSupportURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    public func load() throws -> [SessionScore] {
        let url = try resolvedFileURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sessions = try decoder.decode([SessionScore].self, from: data)
        return sessions.filter(isPlausibleSession)
    }

    public func save(_ sessions: [SessionScore]) throws {
        let url = try resolvedFileURL()
        let directoryURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sessions)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func clear() throws {
        let url = try resolvedFileURL()
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
        guard data.count <= maximumTransferPayloadBytes else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(StatsTransferPayload.self, from: data) else {
            return nil
        }
        if let appIdentifier = payload.appIdentifier,
           appIdentifier != StatsTransferPayload.payloadIdentifier {
            return nil
        }
        guard payload.version == 1 else { return nil }
        guard payload.sessions.count <= maximumTransferSessions else { return nil }
        guard payload.sessions.allSatisfy(isPlausibleSession) else { return nil }
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

    private func isPlausibleSession(_ session: SessionScore) -> Bool {
        isReasonableNLevel(session.startN)
            && isReasonableNLevel(session.endN)
            && isValidAccuracy(session.visualAccuracy)
            && isValidAccuracy(session.audioAccuracy)
            && isValidAccuracy(session.averageAccuracy)
            && isValidCounts(session.visualCounts)
            && isValidCounts(session.audioCounts)
    }

    private func isReasonableNLevel(_ value: Int) -> Bool {
        (GameLimits.minimumNLevel...maximumStoredNLevel).contains(value)
    }

    private func isValidAccuracy(_ value: Double) -> Bool {
        value.isFinite && (0.0...100.0).contains(value)
    }

    private func isValidCounts(_ counts: SessionScore.StreamCounts) -> Bool {
        (0...maximumReasonableCount).contains(counts.hits)
            && (0...maximumReasonableCount).contains(counts.misses)
            && (0...maximumReasonableCount).contains(counts.falsePositives)
    }
}
