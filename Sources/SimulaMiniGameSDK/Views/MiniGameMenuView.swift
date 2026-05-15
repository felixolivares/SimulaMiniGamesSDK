import SwiftUI

/// Native SwiftUI port of the React **`MiniGameMenu`** shell: header, radial backdrop, catalog states, responsive grid/carousel switch.
public struct MiniGameMenuView: View {

    public typealias NavigationKind = MiniGameNavigationKind

    @ObservedObject private var provider: MiniGameProvider
    @Binding private var isPresented: Bool

    private let charName: String
    private let charID: String
    private let charImageURL: URL?
    private let maxGamesToShow: MaxGamesToShow
    private let theme: MiniGameTheme
    private let navigationKind: NavigationKind
    private let onGameOpen: ((String, String) -> Void)?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var charImageFailed = false

    public init(
        provider: MiniGameProvider,
        isPresented: Binding<Bool>,
        charName: String,
        charID: String,
        charImageURL: URL?,
        maxGamesToShow: MaxGamesToShow = .six,
        theme: MiniGameTheme = .default,
        navigationKind: NavigationKind = .dot,
        onGameOpen: ((String, String) -> Void)? = nil
    ) {
        self._provider = ObservedObject(wrappedValue: provider)
        self._isPresented = isPresented
        self.charName = charName
        self.charID = charID
        self.charImageURL = charImageURL
        self.maxGamesToShow = maxGamesToShow
        self.theme = theme
        self.navigationKind = navigationKind
        self.onGameOpen = onGameOpen
    }

    public var body: some View {
        ZStack {
            if isPresented {
                Button {
                    isPresented = false
                } label: {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)

                GeometryReader { geo in
                    let isRegular = horizontalSizeClass == .regular
                    let panelWidth = isRegular ? geo.size.width * 0.95 : geo.size.width * 0.92
                    let panelHeight = isRegular ? geo.size.height * 0.90 : geo.size.height * 0.85

                    VStack(spacing: 0) {
                        modalChrome(isRegular: isRegular)
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
        .task(id: isPresented) {
            guard isPresented else { return }
            charImageFailed = false
            await provider.bootstrapSession()
            await provider.loadCatalog(force: true)
        }
    }

    private var modalBackground: some View {
        ZStack {
            theme.backgroundColor
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

    private func modalChrome(isRegular: Bool) -> some View {
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

                closeButton
                    .padding(.top, 10)
                    .padding(.trailing, 10)
            }
        }
        .padding(.bottom, isRegular ? 20 : 16)
    }

    private var closeButton: some View {
        Button {
            isPresented = false
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.secondaryFontColor)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.08))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .clipShape(Circle())
        }
        .accessibilityLabel(Text("Close menu"))
    }

    /// Pulls the Simula ribbon icon partially over the character tile (RN `MiniGameMenu` stacks ≈‑36 pt).
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
                            .stroke(Color(red: 120 / 255, green: 200 / 255, blue: 255 / 255).opacity(0.1), lineWidth: 2)
                    )
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 10)
                    .zIndex(1)
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 2) {
                Text("Play a Game with")
                    .font(.system(size: titleSize, weight: .black))
                    .foregroundStyle(theme.titleFontColor)
                    .tracking(-0.3)
                Text(charName)
                    .font(.system(size: titleSize, weight: .heavy))
                    .foregroundStyle(theme.titleFontColor.opacity(0.78))
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
                .fill(theme.backgroundColor)

            if let charImageURL, !charImageFailed {
                AsyncImage(url: charImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
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
                    .font(.system(size: horizontalSizeClass == .regular ? 28 : 24, weight: .semibold))
                    .foregroundStyle(theme.titleFontColor)
            }
        }
    }

    /// Decorative Simula “mini-games” pill that rides on the avatar edge (React asset `game icon.png`).
    private var miniGameCompanionBadge: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.32),
                            Color.pink.opacity(0.14),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 30
                    )
                )

            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.85, blue: 1.0),
                            Color.purple.opacity(0.95),
                        ],
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
            if provider.isLoadingCatalog {
                loadingState
            } else if provider.catalogError != nil {
                errorState
            } else if base.isEmpty {
                emptyState
            } else if horizontalSizeClass == .regular {
                MiniGameTabletGridView(
                    games: base,
                    theme: theme,
                    navigationKind: navigationKind,
                    onSelect: { game in
                        handleSelect(game)
                    }
                )
                .padding(.horizontal, isRegular ? 20 : 0)
            } else {
                MiniGamePhoneCarouselView(games: base) { game in
                    handleSelect(game)
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
                .tint(theme.titleFontColor)
                .scaleEffect(1.1)
            Text("Loading games...")
                .font(.system(size: 14))
                .foregroundStyle(theme.secondaryFontColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.backgroundColor)
                    .frame(width: 150, height: 150)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(theme.secondaryFontColor.opacity(0.45))
            }
            Text("No games are available to play right now. Please check back later!")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.secondaryFontColor)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorState: some View {
        emptyState
    }

    private func handleSelect(_ game: GameData) {
        let menuId = provider.catalog?.menuId ?? ""
        Task {
            if !menuId.isEmpty {
                await provider.notifyMenuGameSelected(menuId: menuId, gameName: game.name)
            }
        }
        onGameOpen?(game.name, game.description)
        isPresented = false
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        let letters = parts.compactMap { $0.first }.map { String($0) }
        return letters.prefix(2).joined().uppercased()
    }
}
