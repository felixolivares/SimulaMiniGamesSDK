import SwiftUI

/// Publisher API key referenced in the Simula take-home brief (public sample key).
public enum SimulaAssessmentConfiguration {
    public static let samplePublisherAPIKey = "pub_eeee14c661ce47659a289db29364723a"
    /// Matches the HTLB **`/v3/<domain>/`** path that serves for the **`pub_eeee…`** playground (`200` OK); **`MiniGameWidgetShellURL`'s **`playgroundDefaultBannerDomain`**.
    public static let samplePublisherBannerAdDomain = MiniGameWidgetShellURL.playgroundDefaultBannerDomain
}

/// Root integration sample mirroring a host app root view.
public struct SimulaSampleRootView: View {

    @StateObject private var provider = MiniGameProvider(apiKey: SimulaAssessmentConfiguration.samplePublisherAPIKey)

    public init() {}

    public var body: some View {
        SimulaSampleContentView(provider: provider)
    }
}

/// Demonstrates wiring `MiniGameProvider` + `MiniGameMenuView` similarly to React `SimulaProvider` + `MiniGameMenu`.
public struct SimulaSampleContentView: View {

    @ObservedObject private var provider: MiniGameProvider
    @State private var menuPresented = false
    /// When true, **`MiniGameMenuView`** receives **`themeOverrides`** shaped like a bridged React **`theme`** payload.
    @State private var injectBridgedDemoTheme = false

    private let companionName = "Maya"
    private let companionId = "demo-char"
    private let companionAvatar =
        URL(string: "https://coolaigames.com/maya/_next/image?url=%2Fmaya%2Fmaya-avatar.png&w=256&q=75")

    public init(provider: MiniGameProvider) {
        self._provider = ObservedObject(wrappedValue: provider)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(provider.sessionId ?? "— (still creating or offline)")
                        .font(.footnote)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Catalog snapshot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let catalog = provider.catalog {
                        Text("\(catalog.games.count) games · menu_id \(catalog.menuId)")
                            .font(.footnote)
                    } else if provider.catalogError != nil {
                        Text("Catalog failed — open the menu to retry.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else {
                        Text("Not loaded yet")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("Inject bridged palette (React-style theme patch)", isOn: $injectBridgedDemoTheme)
                    .font(.subheadline)
                    .toggleStyle(.switch)

                Button {
                    menuPresented = true
                } label: {
                    Text("Open mini-game menu")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Simula SDK")
        }
        .overlay {
            MiniGameMenuView(
                provider: provider,
                isPresented: $menuPresented,
                charName: companionName,
                charID: companionId,
                charImageURL: companionAvatar,
                maxGamesToShow: .six,
                theme: .default,
                themeOverrides: injectBridgedDemoTheme ? Self.bridgedDemoThemePatch : nil,
                navigationKind: .dot,
                publisherAdDomain: SimulaAssessmentConfiguration.samplePublisherBannerAdDomain,
                onGameOpen: { name, description in
                    print("[SimulaDemo] Opened \(name): \(description)")
                },
                onGameClose: { name, description in
                    print("[SimulaDemo] Closed \(name): \(description) — exit ad dismissed, menu dismissed")
                },
                onImpression: { ctx in
                    print(
                        "[SimulaDemo] Shell impression placement=\(ctx.placement) game=\(ctx.gameName) id=\(ctx.gameTypeId) serve=\(ctx.serveId ?? "nil") ad=\(ctx.adId ?? "nil") banner=\(ctx.showBanner)"
                    )
                },
                onDestinationOpen: { url in
                    print("[SimulaDemo] Destination open (ad click-through): \(url.absoluteString)")
                }
            )
        }
        .task {
            await provider.bootstrapSession()
            await provider.loadCatalog()
        }
    }

    /// Example payload close to how React passes **`MiniGameTheme`**: hex strings for palette keys a bridge can forward.
    private static let bridgedDemoThemePatch = MiniGameThemePatch(
        titleFontDesign: .rounded,
        secondaryFontDesign: .rounded,
        titleFontColor: .hex("#F1F5F9"),
        secondaryFontColor: .hex("#94A3B8"),
        iconCornerRadius: 14,
        borderColor: .hex("#38BDF8"),
        accentColor: .hex("#A855F7"),
        backgroundColor: .hex("#020617"),
        headerBackgroundColor: .hex("#0F172A"),
        playableBorderColor: .hex("#1E293B"),
        playableHeightPercent: 86
    )
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Sample host") {
    SimulaSampleRootView()
}

@available(iOS 17.0, *)
#Preview("Menu only") {
    struct Harness: View {
        @State private var open = true
        var body: some View {
            Color.black.opacity(0.2)
                .overlay {
                    MiniGameMenuView(
                        provider: MiniGameProvider(apiKey: SimulaAssessmentConfiguration.samplePublisherAPIKey),
                        isPresented: $open,
                        charName: "Maya",
                        charID: "preview",
                        charImageURL: nil,
                        publisherAdDomain: SimulaAssessmentConfiguration.samplePublisherBannerAdDomain,
                        onGameOpen: { name, description in
                            print("[SimulaDemo][Preview] Opened \(name): \(description)")
                        },
                        onGameClose: { name, description in
                            print("[SimulaDemo][Preview] Closed \(name): \(description)")
                        },
                        onImpression: { ctx in
                            print("[SimulaDemo][Preview] Shell impression \(ctx.gameName) banner=\(ctx.showBanner)")
                        }
                    )
                }
        }
    }
    return Harness()
}
#endif
