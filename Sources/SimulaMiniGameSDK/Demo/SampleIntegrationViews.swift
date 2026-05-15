import SwiftUI

/// Publisher API key referenced in the Simula take-home brief (public sample key).
public enum SimulaAssessmentConfiguration {
    public static let samplePublisherAPIKey = "pub_eeee14c661ce47659a289db29364723a"
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
                navigationKind: .dot,
                onGameOpen: { name, description in
                    print("[SimulaDemo] Opened \(name): \(description)")
                }
            )
        }
        .task {
            await provider.bootstrapSession()
            await provider.loadCatalog()
        }
    }
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
                        charImageURL: nil
                    )
                }
        }
    }
    return Harness()
}
#endif
