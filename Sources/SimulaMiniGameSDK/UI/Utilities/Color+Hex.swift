import SwiftUI

extension Color {
    /// Parses `#RRGGBB` / `#RRGGBBAA` hex strings (`React MiniGameTheme` colors).
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("#") else { return nil }
        s.removeFirst()
        guard [6, 8].contains(s.count), s.unicodeScalars.allSatisfy(\.properties.isHexDigit) else { return nil }
        let scanner = Scanner(string: s)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return nil }

        switch s.count {
        case 6:
            self.init(
                red: Double((rgb >> 16) & 0xFF) / 255,
                green: Double((rgb >> 8) & 0xFF) / 255,
                blue: Double(rgb & 0xFF) / 255,
                opacity: 1
            )
        default:
            self.init(
                red: Double((rgb >> 24) & 0xFF) / 255,
                green: Double((rgb >> 16) & 0xFF) / 255,
                blue: Double((rgb >> 8) & 0xFF) / 255,
                opacity: Double(rgb & 0xFF) / 255
            )
        }
    }
}
