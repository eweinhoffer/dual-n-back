import Foundation

public enum SpeechVoice: String, CaseIterable, Identifiable {
    case marin
    case cedar
    case coral

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .marin: "Marin"
        case .cedar: "Cedar"
        case .coral: "Coral"
        }
    }
}
