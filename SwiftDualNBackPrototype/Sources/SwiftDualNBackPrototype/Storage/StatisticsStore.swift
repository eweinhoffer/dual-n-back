import Foundation

struct StatisticsStore {
    private let directoryName = "DualNBack"
    private let fileName = "score_history.json"
    private let fileManager = FileManager.default

    var fileURL: URL {
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

    func load() throws -> [SessionScore] {
        let url = fileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([SessionScore].self, from: data)
    }

    func save(_ sessions: [SessionScore]) throws {
        let url = fileURL
        let directoryURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sessions)
        try data.write(to: url, options: .atomic)
    }

    func clear() throws {
        let url = fileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }
}
