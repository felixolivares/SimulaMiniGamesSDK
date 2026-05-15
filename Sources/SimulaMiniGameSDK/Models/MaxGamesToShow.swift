import Foundation

public enum MaxGamesToShow: Int, Sendable {
    case three = 3
    case six = 6
    case nine = 9

    public static func clamping(_ value: Int) -> MaxGamesToShow {
        if value <= 3 { return .three }
        if value <= 6 { return .six }
        return .nine
    }
}
