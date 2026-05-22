import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Native SwiftUI port of the React **`MiniGameMenu`**: catalogue, playable **`WKWebView`** (via **`/widget/shell`** like **`GameIframe`**), then a full-screen ad overlay with 5 s countdown when the user taps **X** to exit ( **`onGameClose`** after the gated dismiss **X** ).
///
/// ## Top banner (Aditude)
/// The shell loads **`https://htlbid.com/v3/<domain>/htlbid.js`**. Pass your site hostname via **`publisherAdDomain`** (same idea as web **`window.location.hostname`**). **`MiniGameProvider.devMode == true`** maps to **`dev=true`** on the shell document, which **skips all in-shell ad refreshes** (empty black **50 px** band).
///
/// ## Ad click-through (**`onDestinationOpen`**)
/// In **`WKWebView`**, creatives that **`window.open`** / use **`target="_blank"`** are dropped unless the host adopts **`WKUIDelegate`**; we open **`http`/`https`** in Safari (`UIApplication.shared.open`) instead of **`load`** on the embedded web view so **`/widget/shell`** stays intact. **`onDestinationOpen`** also fires for same-frame **`http`/`https`** link activations (**`navigationType`** **`.linkActivated`**) inside the playable or exit interstitial web views — custom URL schemes / JS redirects without link semantics may still not surface here until a future bridge observes **`postMessage`** from the iframe stack.
public struct MiniGameMenuView: View {

    public typealias NavigationKind = MiniGameNavigationKind

    @ObservedObject private var provider: MiniGameProvider
    @Binding private var isPresented: Bool

    private let charName: String
    private let charID: String
    private let charImageURL: URL?
    private let charDescription: String?
    private let maxGamesToShow: MaxGamesToShow
    private let baseTheme: MiniGameTheme
    private let themeOverrides: MiniGameThemePatch?
    private let navigationKind: NavigationKind

    private let messages: [MiniGameMessage]
    private let conversationId: String?
    private let entryPoint: String?
    private let delegateCharacterInGame: Bool

    /// Whether the playable surface should mirror web **`MiniGameMenu` `showBanner`** (passed into **`widget/shell`** as **`show_banner`**).
    private let showBanner: Bool
    /// Hostname for **`widget/shell`'s **`domain`** query (**`https://htlbid.com/v3/<domain>/htlbid.js`**).
    /// Pass your registered property (same idea as web **`window.location.hostname`**).
    /// **`nil`** skips the playable **`iframe_url`** host unless it belongs to **`coolaigames.com`** (CDN hosts alone will not work).
    private let publisherAdDomain: String?

    /// Fires when the playable **`iframe_url`** is displayed (after selection, before any exit ad).
    private let onGameOpen: ((String, String) -> Void)?
    /// Fires after the gated exit interstitial is dismissed and the overlay closes.
    private let onGameClose: ((String, String) -> Void)?
    /// Fires once after the **`/widget/shell`** document finishes loading in the playable **`WKWebView`** while the catalogue game is mounted.
    private let onImpression: ((MiniGameShellImpressionContext) -> Void)?
    /// User-activated navigation to **`http`/`https`** from in-web-view ads / creatives (same-frame links notified here; **`window.open`/`_blank`** opens Safari and notifies here too).
    private let onDestinationOpen: ((URL) -> Void)?

    private var appliedTheme: MiniGameTheme {
        baseTheme.applying(themeOverrides)
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var charImageFailed = false

    private enum MenuFlowState: Equatable {
        case browsing
        case bootstrappingPlayable
        case fetchingInterstitial
        case showingInterstitial
        case showingPlayable
    }

    @State private var menuFlow: MenuFlowState = .browsing

    /// **`WKWebView`** stays mounted under fetch + ad overlays so the game remains visible (dimmed), matching the Simula web shell.
    private var experiencePlayableUnderlaysChrome: Bool {
        guard playPayload != nil else { return false }
        switch menuFlow {
        case .showingPlayable, .fetchingInterstitial, .showingInterstitial:
            return true
        default:
            return false
        }
    }

    @State private var focusedGame: GameData?
    @State private var playPayload: InitMinigameResult?
    @State private var interstitialURL: URL?
    @State private var interstitialSecondsLeft: Int = 0
    @State private var interstitialDismissible: Bool = false
    @State private var countdownTask: Task<Void, Never>?

    @State private var catalogActionError: String?
    @State private var experienceErrorMessage: String?

    private let interstitialGateTotalSeconds = 5

    public init(
        provider: MiniGameProvider,
        isPresented: Binding<Bool>,
        charName: String,
        charID: String,
        charImageURL: URL?,
        charDescription: String? = nil,
        maxGamesToShow: MaxGamesToShow = .six,
        theme: MiniGameTheme = .default,
        themeOverrides: MiniGameThemePatch? = nil,
        navigationKind: NavigationKind = .dot,
        messages: [MiniGameMessage] = [],
        conversationId: String? = nil,
        entryPoint: String? = nil,
        delegateCharacterInGame: Bool = true,
        showBanner: Bool = true,
        publisherAdDomain: String? = nil,
        onGameOpen: ((String, String) -> Void)? = nil,
        onGameClose: ((String, String) -> Void)? = nil,
        onImpression: ((MiniGameShellImpressionContext) -> Void)? = nil,
        onDestinationOpen: ((URL) -> Void)? = nil
    ) {
        self._provider = ObservedObject(wrappedValue: provider)
        self._isPresented = isPresented
        self.charName = charName
        self.charID = charID
        self.charImageURL = charImageURL
        self.charDescription = charDescription
        self.maxGamesToShow = maxGamesToShow
        self.baseTheme = theme
        self.themeOverrides = themeOverrides
        self.navigationKind = navigationKind
        self.messages = messages
        self.conversationId = conversationId
        self.entryPoint = entryPoint
        self.delegateCharacterInGame = delegateCharacterInGame
        self.showBanner = showBanner
        self.publisherAdDomain = publisherAdDomain
        self.onGameOpen = onGameOpen
        self.onGameClose = onGameClose
        self.onImpression = onImpression
        self.onDestinationOpen = onDestinationOpen
    }

    public var body: some View {
        ZStack {
            if isPresented {
                Button {
                    if menuFlow == .browsing {
                        isPresented = false
                    }
                } label: {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .allowsHitTesting(menuFlow == .browsing)

                GeometryReader { geo in
                    let isRegular = horizontalSizeClass == .regular
                    let panelWidth = isRegular ? geo.size.width * 0.95 : geo.size.width * 0.92
                    let panelHeight = isRegular ? geo.size.height * 0.90 : geo.size.height * 0.85

                    Group {
                        if menuFlow == .browsing {
                            browsingPanel(isRegular: isRegular)
                        } else {
                            experiencePanel(panelSize: CGSize(width: panelWidth, height: panelHeight))
                        }
                    }
                    .frame(width: panelWidth, height: panelHeight)
                    .background(modalBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 25, x: 0, y: 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .padding(.horizontal, 0)
            }
        }
        .animation(.easeOut(duration: 0.22), value: isPresented)
        .onChange(of: isPresented) { presented in
            guard !presented else { return }
            resetExperienceState()
            catalogActionError = nil
        }
        .task(id: isPresented) {
            guard isPresented else { return }
            charImageFailed = false
            await provider.bootstrapSession()
            await provider.loadCatalog(force: true)
        }
    }

    private var modalBackground: some View {
        ZStack {
            appliedTheme.backgroundColor
            RadialGradient(
                colors: [
                    Color(red: 96 / 255, green: 165 / 255, blue: 250 / 255).opacity(0.11),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.12, y: 0.16),
                startRadius: 20,
                endRadius: 320
            )
            RadialGradient(
                colors: [
                    Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255).opacity(0.08),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.86, y: 0.24),
                startRadius: 10,
                endRadius: 280
            )
            RadialGradient(
                colors: [
                    Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255).opacity(0.09),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.52, y: 1.15),
                startRadius: 40,
                endRadius: 420
            )
        }
        .allowsHitTesting(false)
    }

    private func browsingPanel(isRegular: Bool) -> some View {
        let headerTop = isRegular ? 10.0 : 12.0
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    header
                        .padding(.top, headerTop)
                        .padding(.horizontal, isRegular ? 20 : 10)
                        .padding(.bottom, isRegular ? 4 : 6)

                    catalogRegion(isRegular: isRegular)
                }

                browsingCloseButton
                    .padding(.top, 10)
                    .padding(.trailing, 10)
            }
        }
        .padding(.bottom, isRegular ? 20 : 16)
    }

    private var browsingCloseButton: some View {
        modalChromeCloseButton(accessibilityLabel: "Close menu") {
            isPresented = false
        }
    }

    private func experiencePanel(panelSize: CGSize) -> some View {
        let toolbarHeight: CGFloat = 52
        let contentArea = max(panelSize.height - toolbarHeight - 28, 200)

        return VStack(spacing: 14) {
            experienceToolbar

            ZStack {
                Group {
                    if experiencePlayableUnderlaysChrome, let payload = playPayload, let game = focusedGame {
                        playableWebRegion(
                            totalHeight: contentArea - 32,
                            playablePayload: payload,
                            focusedGame: game
                        )
                            .allowsHitTesting(menuFlow == .showingPlayable)
                    }

                    switch menuFlow {
                    case .bootstrappingPlayable:
                        experienceLoadingChrome
                    case .fetchingInterstitial:
                        ZStack {
                            Color.black.opacity(0.48)
                                .allowsHitTesting(true)
                            experienceLoadingChrome
                        }
                    case .showingPlayable:
                        EmptyView()
                    case .showingInterstitial:
                        gatedInterstitialChrome(contentHeight: contentArea - 28)
                            .allowsHitTesting(true)
                    case .browsing:
                        EmptyView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    /// Compact **`X`** used in catalogue and experience chrome (matches web mini-game chrome).
    private func modalChromeCloseButton(
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(appliedTheme.secondaryFontColor)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.08))
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var experienceToolbar: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(experienceTitle)
                .font(.system(size: 15, weight: .heavy, design: appliedTheme.titleFontDesign))
                .foregroundStyle(appliedTheme.titleFontColor)

            Spacer(minLength: 4)

            switch menuFlow {
            case .showingPlayable:
                modalChromeCloseButton(accessibilityLabel: "Close game") {
                    Task { await beginInterstitialPhase() }
                }
            case .bootstrappingPlayable:
                modalChromeCloseButton(accessibilityLabel: "Cancel loading") {
                    resetExperienceState()
                }
            case .fetchingInterstitial:
                EmptyView().frame(width: 28, height: 28)
            case .showingInterstitial:
                interstitialGateToolbarAccessory()
            case .browsing:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func interstitialGateToolbarAccessory() -> some View {
        let secondary = appliedTheme.secondaryFontColor

        VStack(alignment: .trailing, spacing: 10) {
            if !interstitialDismissible {
                CircularInterstitialCountdownView(
                    secondsLeft: interstitialSecondsLeft,
                    totalSeconds: interstitialGateTotalSeconds,
                    gateOpened: false,
                    ringColor: .white.opacity(0.9),
                    numberColor: .white
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Ad countdown")
                .accessibilityValue(Text("\(interstitialSecondsLeft) seconds before you can dismiss the ad."))
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if interstitialDismissible {
                Button(action: acknowledgeGatedAd) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(secondary.opacity(0.96))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.24), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Dismiss advertisement"))
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .fixedSize()
        .animation(.easeOut(duration: 0.2), value: interstitialDismissible)
    }

    private var experienceTitle: String {
        switch menuFlow {
        case .bootstrappingPlayable:
            return "Loading game…"
        case .showingPlayable:
            return focusedGame?.name ?? "Mini-game"
        case .fetchingInterstitial:
            return "Loading ad…"
        case .showingInterstitial:
            return "Thanks for playing"
        case .browsing:
            return ""
        }
    }

    private var experienceLoadingChrome: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(appliedTheme.accentColor)
            Text(loadingSubtitle)
                .font(.footnote)
                .foregroundStyle(appliedTheme.secondaryFontColor)

            if let banner = experienceErrorMessage {
                Text(banner)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.red.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                Button("Back to catalog") {
                    experienceErrorMessage = nil
                    menuFlow = .browsing
                }
                .font(.footnote.bold())
                .foregroundStyle(appliedTheme.accentColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(24)
    }

    private var loadingSubtitle: String {
        menuFlow == .fetchingInterstitial ? "Fetching advertisement…" : "Preparing playable experience…"
    }

    private func playableWebRegion(
        totalHeight: CGFloat,
        playablePayload: InitMinigameResult,
        focusedGame: GameData
    ) -> some View {
        let shellURL = MiniGameWidgetShellURL.gameShellURL(
            gamePlayableURL: playablePayload.iframeURL,
            publisherAdDomain: publisherAdDomain,
            showBanner: showBanner,
            devMode: provider.devMode
        )
        return SimulaIframeWebView(
            url: shellURL,
            onPrimaryDocumentLoad: {
                let impression = MiniGameShellImpressionContext(
                    placement: "widget_shell",
                    gameTypeId: focusedGame.id,
                    gameName: focusedGame.name,
                    serveId: playablePayload.serveId,
                    adId: playablePayload.adId,
                    showBanner: showBanner
                )
                onImpression?(impression)
            },
            onDestinationOpen: onDestinationOpen
        )
        .frame(height: playableChromeHeight(for: totalHeight))
        .clipShape(RoundedRectangle(cornerRadius: appliedTheme.iconCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: appliedTheme.iconCornerRadius, style: .continuous)
                .stroke(appliedTheme.cardHighlightStrokeColor, lineWidth: 1)
        )
    }

    private func gatedInterstitialChrome(contentHeight: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.62)
                .allowsHitTesting(true)

            VStack(spacing: 14) {
                Text("AD")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .tracking(3.8)

                interstitialAdvertCard(for: contentHeight)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
            .allowsHitTesting(true)
        }
    }

    /// Centered rectangular ad matching the Simula mobile web layout (IFrame or placeholder fallback).
    @ViewBuilder
    private func interstitialAdvertCard(for contentHeight: CGFloat) -> some View {
        let maxCardHeight = min(playableChromeHeight(for: contentHeight - 108), CGFloat(420))

        Group {
            if let interstitialURL {
                SimulaIframeWebView(url: interstitialURL, onDestinationOpen: onDestinationOpen)
                    .background(Color.white)
                    .clipShape(Rectangle())
            } else {
                Rectangle()
                    .fill(Color.white)
                    .frame(height: min(maxCardHeight, 320))
                    .overlay(simulatedAdvertPlaceholder)
                    .overlay(
                        Rectangle()
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
            }
        }
        .frame(height: max(220, maxCardHeight))
        .frame(maxWidth: 294)
        .shadow(color: .black.opacity(0.42), radius: 24, x: 0, y: 14)
        .allowsHitTesting(true)
    }

    private var simulatedAdvertPlaceholder: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.square.filled.on.square")
                .font(.system(size: 34))
                .foregroundStyle(Color.yellow.opacity(0.92))
                .padding(.top, 10)

            Text(provider.devMode ? "DEV FALLBACK INTERSTITIAL" : "PARTNER ADVERTISEMENT")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.88))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black)
                .frame(height: 48)
                .overlay(
                    Text("Explore offer")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.94))
                )
                .padding(.horizontal, 20)

            Text("Special placement while we load or when no iframe URL was returned.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.52))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private func playableChromeHeight(for available: CGFloat) -> CGFloat {
        switch appliedTheme.playableSizing {
        case .fullscreen:
            return max(260, available)
        case .heightPoints(let pts):
            return min(max(260, pts), available)
        case .heightPercent(let pct):
            let clamped = min(max(Double(pct), 30), 100)
            return max(260, available * CGFloat(clamped / 100))
        }
    }

    private var avatarGameIconOverlap: CGFloat {
        horizontalSizeClass == .regular ? -36 : -34
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack(alignment: .leading) {
                miniGameCompanionBadge
                    .offset(x: avatarSize.width + avatarGameIconOverlap)
                    .zIndex(0)

                avatar
                    .frame(width: avatarSize.width, height: avatarSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: avatarCornerOuter, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: avatarCornerOuter, style: .continuous)
                            .stroke(appliedTheme.cardHighlightStrokeColor, lineWidth: 2)
                    )
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 10)
                    .zIndex(1)
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 2) {
                Text("Play a Game with")
                    .font(.system(size: titleSize, weight: .black, design: appliedTheme.titleFontDesign))
                    .foregroundStyle(appliedTheme.titleFontColor)
                    .tracking(-0.3)
                Text(charName)
                    .font(.system(size: titleSize, weight: .heavy, design: appliedTheme.titleFontDesign))
                    .foregroundStyle(appliedTheme.titleFontColor.opacity(0.78))
                    .tracking(-0.3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 8)
    }

    private var avatarSize: CGSize {
        horizontalSizeClass == .regular ? CGSize(width: 80, height: 80) : CGSize(width: 72, height: 72)
    }

    private var avatarCornerOuter: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }

    private var titleSize: CGFloat {
        horizontalSizeClass == .regular ? 19 : 18
    }

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: avatarCornerOuter, style: .continuous)
                .fill(appliedTheme.backgroundColor)

            if let charImageURL, !charImageFailed {
                AsyncImage(url: charImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.clear.onAppear { charImageFailed = true }
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Text(initials(from: charName))
                    .font(.system(size: horizontalSizeClass == .regular ? 28 : 24, weight: .semibold, design: appliedTheme.titleFontDesign))
                    .foregroundStyle(appliedTheme.titleFontColor)
            }
        }
    }

    private var miniGameCompanionBadge: some View {
        ZStack {
            Circle().fill(
                RadialGradient(
                    colors: [Color.purple.opacity(0.32), Color.pink.opacity(0.14), Color.clear],
                    center: .center,
                    startRadius: 2,
                    endRadius: 30
                )
            )
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.85, blue: 1.0), Color.purple.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func catalogRegion(isRegular: Bool) -> some View {
        let base = catalogGames
        Group {
            if let banner = catalogActionError {
                Text(banner)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.red.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, isRegular ? 20 : 10)
                    .padding(.bottom, 8)
                    .onTapGesture { catalogActionError = nil }
            }

            if provider.isLoadingCatalog {
                loadingState
            } else if provider.catalogError != nil {
                errorState
            } else if base.isEmpty {
                emptyState
            } else if horizontalSizeClass == .regular {
                MiniGameTabletGridView(
                    games: base,
                    theme: appliedTheme,
                    navigationKind: navigationKind,
                    onSelect: { game in Task { await selectGame(game) } }
                )
                .padding(.horizontal, isRegular ? 20 : 0)
            } else {
                MiniGamePhoneCarouselView(games: base, cardBorderStrokeColor: appliedTheme.cardHighlightStrokeColor) { game in
                    Task { await selectGame(game) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var catalogGames: [GameData] {
        let raw = provider.catalog?.games ?? []
        return Array(raw.prefix(maxGamesToShow.rawValue))
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(appliedTheme.titleFontColor)
                .scaleEffect(1.1)
            Text("Loading games...")
                .font(.system(size: 14, design: appliedTheme.secondaryFontDesign))
                .foregroundStyle(appliedTheme.secondaryFontColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(appliedTheme.backgroundColor)
                    .frame(width: 150, height: 150)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(appliedTheme.secondaryFontColor.opacity(0.45))
            }
            Text("No games are available to play right now. Please check back later!")
                .font(.system(size: 14, design: appliedTheme.secondaryFontDesign))
                .multilineTextAlignment(.center)
                .foregroundStyle(appliedTheme.secondaryFontColor)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorState: some View { emptyState }

    @MainActor
    private func selectGame(_ game: GameData) async {
        guard menuFlow == .browsing else { return }
        guard provider.sessionId != nil else {
            catalogActionError = "No active session — wait until the SDK connects."
            return
        }

        experienceErrorMessage = nil
        catalogActionError = nil
        focusedGame = game
        menuFlow = .bootstrappingPlayable

        let menuId = provider.catalog?.menuId ?? ""
        if !menuId.isEmpty {
            await provider.notifyMenuGameSelected(menuId: menuId, gameName: game.name)
        }

        let size = viewportPointsApproximation()
        do {
            let payload = try await provider.bootstrapPlayableMinigame(
                gameTypeId: game.id,
                viewportWidth: Int(max(320, size.width)),
                viewportHeight: Int(max(320, size.height)),
                characterId: charID,
                characterName: charName,
                characterImageURL: charImageURL,
                characterDescription: charDescription ?? game.description,
                messages: messages,
                delegateCharacterInGame: delegateCharacterInGame,
                menuId: menuId.isEmpty ? nil : menuId,
                conversationId: conversationId,
                entryPoint: entryPoint
            )
            playPayload = payload
            menuFlow = .showingPlayable
            onGameOpen?(game.name, game.description)
        } catch {
            menuFlow = .browsing
            focusedGame = nil
            playPayload = nil
            catalogActionError = "Could not start this game (\(describeError(error))). Tap to dismiss."
        }
    }

    @MainActor
    private func beginInterstitialPhase() async {
        guard focusedGame != nil else {
            resetExperienceState()
            return
        }
        guard provider.sessionId != nil else {
            experienceErrorMessage = "Session expired — close and reopen the menu."
            menuFlow = .showingPlayable
            return
        }
        guard playPayload != nil else {
            resetExperienceState()
            return
        }

        await runExitInterstitialFlow()
    }

    /// Fetch and show the post-close interstitial ( **`Close game`** ), then gate dismiss with the countdown UI.
    @MainActor
    private func runExitInterstitialFlow() async {
        guard let bundle = playPayload else {
            resetExperienceState()
            return
        }

        guard provider.sessionId != nil else {
            experienceErrorMessage = "Session expired — close and reopen the menu."
            menuFlow = .showingPlayable
            return
        }

        experienceErrorMessage = nil
        menuFlow = .fetchingInterstitial

        do {
            let url: URL?
            if let aid = bundle.adId {
                url = try await provider.fetchPostGameInterstitialURL(adId: aid)
            } else {
                url = nil
            }

            let source: MiniGameAdInterstitialSource
            switch (provider.devMode, url != nil) {
            case (true, _):
                source = .aditude
            case (_, true):
                source = .simula
            default:
                source = .none
            }

            await provider.reportMiniGameAdInterstitial(
                serveId: bundle.serveId,
                adSource: source,
                renderedFormat: "iframe"
            )

            interstitialURL = url
            menuFlow = .showingInterstitial
            startInterstitialCountdown()
        } catch {
            experienceErrorMessage = "Could not load the interstitial (\(describeError(error)))."
            menuFlow = .showingPlayable
        }
    }

    @MainActor
    private func acknowledgeGatedAd() {
        guard interstitialDismissible else { return }
        guard menuFlow == .showingInterstitial else { return }

        countdownTask?.cancel()
        countdownTask = nil

        finishPostRollInterstitialAndDismissSheet()
    }

    private func describeError(_ error: Error) -> String {
        if let le = error as? LocalizedError {
            return le.errorDescription ?? le.localizedDescription
        }
        return error.localizedDescription
    }

    private func startInterstitialCountdown() {
        countdownTask?.cancel()
        interstitialDismissible = false
        interstitialSecondsLeft = interstitialGateTotalSeconds

        countdownTask = Task { @MainActor in
            for remaining in stride(from: interstitialGateTotalSeconds, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                interstitialSecondsLeft = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            guard !Task.isCancelled else { return }
            interstitialSecondsLeft = 0
            interstitialDismissible = true
        }
    }

    /// Post-roll dismissal: resets local state, informs **`onGameClose`**, closes the catalogue sheet.
    private func finishPostRollInterstitialAndDismissSheet() {
        let game = focusedGame
        countdownTask?.cancel()
        countdownTask = nil
        resetExperienceState()
        if let game {
            onGameClose?(game.name, game.description)
        }
        isPresented = false
    }

    @MainActor
    private func resetExperienceState() {
        countdownTask?.cancel()
        countdownTask = nil
        menuFlow = .browsing
        focusedGame = nil
        playPayload = nil
        interstitialURL = nil
        interstitialDismissible = false
        interstitialSecondsLeft = 0
        experienceErrorMessage = nil
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        let letters = parts.compactMap(\.first).map { String($0) }
        return letters.prefix(2).joined().uppercased()
    }

    private func viewportPointsApproximation() -> CGSize {
#if canImport(UIKit)
        UIScreen.main.bounds.size
#else
        CGSize(width: 390, height: 844)
#endif
    }

    /// Circular countdown paired with gated interstitial dismissals (matches Simula mobile web pattern).
    private struct CircularInterstitialCountdownView: View {
        let secondsLeft: Int
        let totalSeconds: Int
        let gateOpened: Bool

        var ringColor: Color = .white
        var numberColor: Color = .white

        private var progressRatio: CGFloat {
            guard totalSeconds > 0 else { return 0 }
            if gateOpened {
                return 1
            }
            return CGFloat(max(secondsLeft, 0)) / CGFloat(totalSeconds)
        }

        var body: some View {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.28), lineWidth: 4)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: progressRatio)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 40, height: 40)
                    .animation(.easeInOut(duration: 0.15), value: progressRatio)

                if gateOpened {
                    Color.clear.frame(width: 4, height: 4)
                        .accessibilityHidden(true)
                } else {
                    Text(displayLabelSeconds)
                        .font(.system(size: 17, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(numberColor)
                        .minimumScaleFactor(0.82)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: gateOpened)
        }

        private var displayLabelSeconds: String {
            String(max(secondsLeft, 1))
        }
    }
}
