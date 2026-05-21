import SwiftUI

/// How tall the inlined **WKWebView** game shell should render (mirrors **`playableHeight`** in React).
public enum MiniGamePlayableSizing: Equatable, Sendable {
    case fullscreen
    case heightPoints(CGFloat)
    /// 0 ... 100 (percentage of the visible screen height when the overlay is presented).
    case heightPercent(CGFloat)
}

/// Native styling configuration for **`MiniGameMenuView`** chrome + iframe chrome.
///
/// React passes `theme={{ ...partial }}`; use **`MiniGameThemePatch`** for the partial override pattern.
public struct MiniGameTheme: Equatable {

    public var titleFontDesign: Font.Design
    public var secondaryFontDesign: Font.Design
    public var titleFontColor: Color
    public var secondaryFontColor: Color
    public var iconCornerRadius: CGFloat
    /// Subtle cyan stroke drawn on avatar / cards (distinct from **`cardBorderAccentColor`** in RN border usage).
    public var cardHighlightStrokeColor: Color
    /// Card outer stroke approximation of React `MiniGameTheme.borderColor`.
    public var cardBorderAccentColor: Color
    /// Pagination / pagination controls (`accentColor`).
    public var accentColor: Color
    /// Modal backdrop fill (`backgroundColor`).
    public var backgroundColor: Color
    /// Header stripe tint when `MiniGameThemePatch.headerBackgroundColor` is provided.
    public var headerBackgroundColor: Color
    /// Area above playable iframe when **`playableSizing`** is not fullscreen (`playableBorderColor`).
    public var playableChromeColor: Color
    public var playableSizing: MiniGamePlayableSizing

    public init(
        titleFontDesign: Font.Design = .default,
        secondaryFontDesign: Font.Design = .default,
        titleFontColor: Color = .white,
        secondaryFontColor: Color = Color.white.opacity(0.75),
        iconCornerRadius: CGFloat = 8,
        cardHighlightStrokeColor: Color = Color(red: 120 / 255, green: 200 / 255, blue: 255 / 255).opacity(0.1),
        cardBorderAccentColor: Color = Color.white.opacity(0.06),
        accentColor: Color = Color(red: 0.231, green: 0.509, blue: 0.965),
        backgroundColor: Color = Color(red: 0.043, green: 0.043, blue: 0.059),
        headerBackgroundColor: Color = Color.clear,
        playableChromeColor: Color = Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255),
        playableSizing: MiniGamePlayableSizing = .fullscreen
    ) {
        self.titleFontDesign = titleFontDesign
        self.secondaryFontDesign = secondaryFontDesign
        self.titleFontColor = titleFontColor
        self.secondaryFontColor = secondaryFontColor
        self.iconCornerRadius = iconCornerRadius
        self.cardHighlightStrokeColor = cardHighlightStrokeColor
        self.cardBorderAccentColor = cardBorderAccentColor
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.headerBackgroundColor = headerBackgroundColor
        self.playableChromeColor = playableChromeColor
        self.playableSizing = playableSizing
    }

    public static let `default` = MiniGameTheme()

    public func applying(_ patch: MiniGameThemePatch?) -> MiniGameTheme {
        guard let patch else { return self }
        func c(_ overlay: MiniGameThemePatch.ColorOverride?, base: Color) -> Color {
            guard let overlay else { return base }
            switch overlay {
            case .literal(let color):
                return color
            case .hex(let string):
                return Color(hex: string) ?? base
            }
        }

        return MiniGameTheme(
            titleFontDesign: patch.titleFontDesign ?? titleFontDesign,
            secondaryFontDesign: patch.secondaryFontDesign ?? secondaryFontDesign,
            titleFontColor: c(patch.titleFontColor, base: titleFontColor),
            secondaryFontColor: c(patch.secondaryFontColor, base: secondaryFontColor),
            iconCornerRadius: patch.iconCornerRadius ?? iconCornerRadius,
            cardHighlightStrokeColor: c(patch.borderColor, base: cardHighlightStrokeColor),
            cardBorderAccentColor: c(patch.borderColor, base: cardBorderAccentColor),
            accentColor: c(patch.accentColor, base: accentColor),
            backgroundColor: c(patch.backgroundColor, base: backgroundColor),
            headerBackgroundColor: c(patch.headerBackgroundColor, base: headerBackgroundColor),
            playableChromeColor: c(patch.playableBorderColor, base: playableChromeColor),
            playableSizing: patch.resolvedPlayableSizing ?? playableSizing
        )
    }
}

/// Partial overrides matching React’s optional `theme={{ ... }}` object.
///
/// Prefer **`ColorOverride.hex`** strings for parity with the JavaScript palette.
public struct MiniGameThemePatch: Equatable, Sendable {

    public enum ColorOverride: Equatable, Sendable {
        case literal(Color)
        case hex(String)
    }

    public var titleFontDesign: Font.Design?
    public var secondaryFontDesign: Font.Design?
    public var titleFontColor: ColorOverride?
    public var secondaryFontColor: ColorOverride?
    public var iconCornerRadius: CGFloat?
    /// React `borderColor` — blended into divider strokes + avatar outline.
    public var borderColor: ColorOverride?
    public var accentColor: ColorOverride?
    public var backgroundColor: ColorOverride?
    /// React `headerColor`.
    public var headerBackgroundColor: ColorOverride?
    /// React `playableBorderColor`.
    public var playableBorderColor: ColorOverride?
    public var playableHeightPixels: CGFloat?
    public var playableHeightPercent: CGFloat?

    public init(
        titleFontDesign: Font.Design? = nil,
        secondaryFontDesign: Font.Design? = nil,
        titleFontColor: ColorOverride? = nil,
        secondaryFontColor: ColorOverride? = nil,
        iconCornerRadius: CGFloat? = nil,
        borderColor: ColorOverride? = nil,
        accentColor: ColorOverride? = nil,
        backgroundColor: ColorOverride? = nil,
        headerBackgroundColor: ColorOverride? = nil,
        playableBorderColor: ColorOverride? = nil,
        playableHeightPixels: CGFloat? = nil,
        playableHeightPercent: CGFloat? = nil
    ) {
        self.titleFontDesign = titleFontDesign
        self.secondaryFontDesign = secondaryFontDesign
        self.titleFontColor = titleFontColor
        self.secondaryFontColor = secondaryFontColor
        self.iconCornerRadius = iconCornerRadius
        self.borderColor = borderColor
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.headerBackgroundColor = headerBackgroundColor
        self.playableBorderColor = playableBorderColor
        self.playableHeightPixels = playableHeightPixels
        self.playableHeightPercent = playableHeightPercent
    }

    /// Convenience ctor when you only tweak a few `#RRGGBB` knobs.
    public static func accents(
        backgroundHex: String? = nil,
        accentHex: String? = nil,
        borderHex: String? = nil
    ) -> MiniGameThemePatch {
        MiniGameThemePatch(
            borderColor: borderHex.map { .hex($0) },
            accentColor: accentHex.map { .hex($0) },
            backgroundColor: backgroundHex.map { .hex($0) }
        )
    }

    var resolvedPlayableSizing: MiniGamePlayableSizing? {
        if let playableHeightPixels {
            return .heightPoints(playableHeightPixels)
        }
        if let playableHeightPercent {
            return .heightPercent(playableHeightPercent)
        }
        return nil
    }
}
