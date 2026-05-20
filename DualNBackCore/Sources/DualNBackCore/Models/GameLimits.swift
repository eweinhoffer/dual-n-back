import Foundation

public enum GameLimits {
    public static let minimumNLevel = 1
    public static let maximumNLevel = 8

    public static var nLevelRange: ClosedRange<Int> {
        minimumNLevel...maximumNLevel
    }

    public static func clampedNLevel(_ value: Int) -> Int {
        min(max(value, minimumNLevel), maximumNLevel)
    }

    public static func isValidNLevel(_ value: Int) -> Bool {
        nLevelRange.contains(value)
    }
}
