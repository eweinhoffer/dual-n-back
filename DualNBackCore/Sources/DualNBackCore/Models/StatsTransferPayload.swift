import Foundation

public struct StatsTransferPayload: Codable {
    public static let payloadIdentifier = "io.dualnback.stats"

    public let appIdentifier: String?
    public let version: Int
    public let sessions: [SessionScore]

    public init(version: Int = 1, sessions: [SessionScore]) {
        self.appIdentifier = Self.payloadIdentifier
        self.version = version
        self.sessions = sessions
    }

    private enum CodingKeys: String, CodingKey {
        case appIdentifier
        case version
        case sessions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.appIdentifier = try container.decodeIfPresent(String.self, forKey: .appIdentifier)
        self.version = try container.decode(Int.self, forKey: .version)
        self.sessions = try container.decode([SessionScore].self, forKey: .sessions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(appIdentifier, forKey: .appIdentifier)
        try container.encode(version, forKey: .version)
        try container.encode(sessions, forKey: .sessions)
    }
}
