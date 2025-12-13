import Foundation

/// Power mode for battery optimization
enum PowerMode: Int {
    case performance = 0
    case balanced = 1
    case powerSaver = 2
    case ultraLowPower = 3

    static func fromInt(_ value: Int) -> PowerMode {
        return PowerMode(rawValue: value) ?? .balanced
    }
}

