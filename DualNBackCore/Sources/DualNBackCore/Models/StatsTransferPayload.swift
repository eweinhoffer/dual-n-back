import Foundation

public struct StatsTransferPayload: Codable {
    public let version: Int
    public let sessions: [SessionScore]

    public init(version: Int = 1, sessions: [SessionScore]) {
        self.version = version
        self.sessions = sessions
    }
}
