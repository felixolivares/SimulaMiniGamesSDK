import SwiftUI

/// Mirrors `MiniGameTheme` from the React SDK (subset used by the native menu).
public struct MiniGameTheme {
    public var titleFontDesign: Font.Design
    public var secondaryFontDesign: Font.Design
    public var titleFontColor: Color
    public var secondaryFontColor: Color
    public var iconCornerRadius: CGFloat
    public var borderColor: Color
    public var accentColor: Color
    public var backgroundColor: Color

    public init(
        titleFontDesign: Font.Design = .default,
        secondaryFontDesign: Font.Design = .default,
        titleFontColor: Color = .white,
        secondaryFontColor: Color = Color.white.opacity(0.75),
        iconCornerRadius: CGFloat = 8,
        borderColor: Color = Color.white.opacity(0.06),
        accentColor: Color = Color(red: 0.231, green: 0.509, blue: 0.965),
        backgroundColor: Color = Color(red: 0.043, green: 0.043, blue: 0.059)
    ) {
        self.titleFontDesign = titleFontDesign
        self.secondaryFontDesign = secondaryFontDesign
        self.titleFontColor = titleFontColor
        self.secondaryFontColor = secondaryFontColor
        self.iconCornerRadius = iconCornerRadius
        self.borderColor = borderColor
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
    }

    public static let `default` = MiniGameTheme()
}
