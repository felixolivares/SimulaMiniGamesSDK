import Foundation
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
    /// Optional override for **`"Play a game with"`** / hero typography (catalog header). **`nil`** → adaptive **18 / 19 pt**.
    public var catalogHeroTitlePointSize: CGFloat?
    /// Toolbar title during playable / loading / interstitial (**`experienceToolbar`**).
    /// **`nil`** → **`max(13, heroPoints − 3)`** when hero overridden, otherwise **15 pt**.
    public var experienceToolbarTitlePointSize: CGFloat?
    /// Pagination / muted footer copy (compact layout). **`nil`** → **14 pt**.
    public var secondaryBodyPointSize: CGFloat?
    /// Game tiles (`GameCoverCardView` footer label). **`nil`** → **17 pt**.
    public var catalogCoverTitlePointSize: CGFloat?
    public var iconCornerRadius: CGFloat
    /// If **`nil`**, catalog cards use **`max(iconCornerRadius, 14 pt)`** — keeps iframe corners independent from posters.
    public var catalogCoverCornerRadius: CGFloat?
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
        catalogHeroTitlePointSize: CGFloat? = nil,
        experienceToolbarTitlePointSize: CGFloat? = nil,
        secondaryBodyPointSize: CGFloat? = nil,
        catalogCoverTitlePointSize: CGFloat? = nil,
        iconCornerRadius: CGFloat = 8,
        catalogCoverCornerRadius: CGFloat? = nil,
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
        self.catalogHeroTitlePointSize = catalogHeroTitlePointSize
        self.experienceToolbarTitlePointSize = experienceToolbarTitlePointSize
        self.secondaryBodyPointSize = secondaryBodyPointSize
        self.catalogCoverTitlePointSize = catalogCoverTitlePointSize
        self.iconCornerRadius = iconCornerRadius
        self.catalogCoverCornerRadius = catalogCoverCornerRadius
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
            catalogHeroTitlePointSize: patch.catalogHeroTitlePointSize ?? catalogHeroTitlePointSize,
            experienceToolbarTitlePointSize: patch.experienceToolbarTitlePointSize ?? experienceToolbarTitlePointSize,
            secondaryBodyPointSize: patch.secondaryBodyPointSize ?? secondaryBodyPointSize,
            catalogCoverTitlePointSize: patch.catalogCoverTitlePointSize ?? catalogCoverTitlePointSize,
            iconCornerRadius: patch.iconCornerRadius ?? iconCornerRadius,
            catalogCoverCornerRadius: patch.catalogCoverCornerRadius ?? catalogCoverCornerRadius,
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

extension MiniGameTheme {

    /// Rounded rects on catalog poster tiles (**`GameCoverCardView`**).
    public var resolvedCatalogCoverCornerRadius: CGFloat {
        catalogCoverCornerRadius ?? Swift.max(iconCornerRadius, 14)
    }

    /// Body / pagination baseline (SwiftUI compact footer + grids).
    public var resolvedSecondaryBodyPoints: CGFloat {
        secondaryBodyPointSize ?? 14
    }

    /// Slightly larger than **`resolvedSecondaryBodyPoints`** — matches legacy **16 pt** pagination glyphs when **`secondaryBodyPointSize`** is unset.
    public var resolvedPaginationLabelPoints: CGFloat {
        Swift.max(resolvedSecondaryBodyPoints + 2, 13)
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
    public var catalogHeroTitlePointSize: CGFloat?
    public var experienceToolbarTitlePointSize: CGFloat?
    public var secondaryBodyPointSize: CGFloat?
    public var catalogCoverTitlePointSize: CGFloat?
    public var iconCornerRadius: CGFloat?
    /// If set, **`GameCoverCardView`** rounding; **`iconCornerRadius`** still shapes iframe chrome independently.
    public var catalogCoverCornerRadius: CGFloat?
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
        catalogHeroTitlePointSize: CGFloat? = nil,
        experienceToolbarTitlePointSize: CGFloat? = nil,
        secondaryBodyPointSize: CGFloat? = nil,
        catalogCoverTitlePointSize: CGFloat? = nil,
        iconCornerRadius: CGFloat? = nil,
        catalogCoverCornerRadius: CGFloat? = nil,
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
        self.catalogHeroTitlePointSize = catalogHeroTitlePointSize
        self.experienceToolbarTitlePointSize = experienceToolbarTitlePointSize
        self.secondaryBodyPointSize = secondaryBodyPointSize
        self.catalogCoverTitlePointSize = catalogCoverTitlePointSize
        self.iconCornerRadius = iconCornerRadius
        self.catalogCoverCornerRadius = catalogCoverCornerRadius
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

// MARK: - React Native bridging (`NSDictionary` → patch)

extension MiniGameThemePatch {

    /// Builds a **`MiniGameThemePatch`** from a React Native **`NSDictionary`** (**`RCT_EXPORT_VIEW_PROPERTY(theme, NSDictionary)`**).
    public static func bridging(fromJSObject object: Any?) -> MiniGameThemePatch? {
        guard let dict = object as? NSDictionary else { return nil }
        guard dict.count > 0 else { return nil }

        func any(_ keys: [String]) -> Any? {
            for key in keys {
                guard let value = dict[key] else { continue }
                guard !(value is NSNull) else { continue }
                return value
            }
            return nil
        }

        func string(_ keys: [String]) -> String? {
            guard let raw = any(keys) else { return nil }
            if let str = raw as? String { return str }
            if let str = raw as? NSString { return str as String }
            return nil
        }

        func cgFloat(_ keys: [String]) -> CGFloat? {
            guard let raw = any(keys) else { return nil }
            if let num = raw as? NSNumber { return CGFloat(truncating: num) }
            if let str = raw as? String {
                let t = str.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                guard !t.isEmpty, let double = Double(t) else { return nil }
                return CGFloat(double)
            }
            return nil
        }

        func colorOverride(hexKeys: [String]) -> MiniGameThemePatch.ColorOverride? {
            guard let hex = string(hexKeys), !hex.isEmpty else { return nil }
            return .hex(hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        }

        func fontDesign(_ keys: [String]) -> Font.Design? {
            guard let raw = string(keys) else { return nil }
            let s = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
            guard !s.isEmpty else { return nil }
            if s.contains("mono") || s == "monospaced" || s == "mono" {
                return .monospaced
            }
            if s.contains("serif") || s.contains("literata") || s.contains("times") || s.contains("georgia") {
                return .serif
            }
            if s.contains("rounded") || s.contains("sf pro rounded") || s == "rounded" {
                return .rounded
            }
            return .default
        }

        var playablePx: CGFloat?
        var playablePct: CGFloat?
        if let heightValue = any(["playableHeight", "playable_height"]) {
            if let num = heightValue as? NSNumber {
                playablePx = CGFloat(truncating: num)
            } else if let ns = heightValue as? NSString {
                let trimmed = ns.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if trimmed.hasSuffix("%") {
                    let body = trimmed.dropLast().trimmingCharacters(in: CharacterSet.whitespaces)
                    if let pct = Double(body), pct > 0 {
                        playablePct = CGFloat(min(pct, 100))
                    }
                } else if let px = Double(trimmed), px > 0 {
                    playablePx = CGFloat(px)
                }
            } else if let str = heightValue as? String {
                let trimmed = str.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if trimmed.hasSuffix("%") {
                    let body = trimmed.dropLast().trimmingCharacters(in: CharacterSet.whitespaces)
                    if let pct = Double(body), pct > 0 {
                        playablePct = CGFloat(min(pct, 100))
                    }
                } else if let px = Double(trimmed), px > 0 {
                    playablePx = CGFloat(px)
                }
            }
        }

        return MiniGameThemePatch(
            titleFontDesign: fontDesign(["titleFont", "title_font", "title_font_family"]),
            secondaryFontDesign: fontDesign(["secondaryFont", "secondary_font", "secondary_font_family"]),
            titleFontColor: colorOverride(hexKeys: ["titleFontColor", "title_font_color"]),
            secondaryFontColor: colorOverride(hexKeys: ["secondaryFontColor", "secondary_font_color"]),
            catalogHeroTitlePointSize: cgFloat(["titleFontSize", "title_font_size"]),
            experienceToolbarTitlePointSize: cgFloat([
                "experienceTitleFontSize", "experience_title_font_size", "toolbarTitleFontSize", "toolbar_title_font_size",
            ]),
            secondaryBodyPointSize: cgFloat(["secondaryFontSize", "secondary_font_size"]),
            catalogCoverTitlePointSize: cgFloat(["cardTitleFontSize", "card_title_font_size", "catalogCardTitleFontSize"]),
            iconCornerRadius: cgFloat(["iconCornerRadius", "icon_corner_radius"]),
            catalogCoverCornerRadius: cgFloat([
                "catalogCardCornerRadius", "catalog_card_corner_radius", "gameCardCornerRadius", "coverCornerRadius",
            ]),
            borderColor: colorOverride(hexKeys: ["borderColor", "border_color"]),
            accentColor: colorOverride(hexKeys: ["accentColor", "accent_color"]),
            backgroundColor: colorOverride(hexKeys: ["backgroundColor", "background_color"]),
            headerBackgroundColor: colorOverride(hexKeys: ["headerColor", "header_color"]),
            playableBorderColor: colorOverride(hexKeys: ["playableBorderColor", "playable_border_color"]),
            playableHeightPixels: playablePx,
            playableHeightPercent: playablePct
        )
    }
}
