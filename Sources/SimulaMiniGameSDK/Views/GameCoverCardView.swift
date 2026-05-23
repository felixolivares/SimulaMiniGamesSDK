import SwiftUI

/// Portrait cover tile matching React `CoverCard`.
struct GameCoverCardView: View {
    let game: GameData
    let cornerRadius: CGFloat
    /// Outer stroke for the tile (maps to React `borderColor` / highlight).
    let borderStrokeColor: Color
    let onSelect: () -> Void

    @State private var imageStage: ImageLoadStage = .primary

    private enum ImageLoadStage: Int {
        case primary // gif or icon (same as RN first load)
        case iconOnly
        case fallbackEmoji
    }

    private let fallbackEmojis = ["🎲", "🎮", "🎯", "🧩"]

    let gameCoverTitlePoints: CGFloat

    init(
        game: GameData,
        cornerRadius: CGFloat = 18,
        gameCoverTitlePoints: CGFloat = 17,
        borderStrokeColor: Color = Color(red: 120 / 255, green: 200 / 255, blue: 255 / 255).opacity(0.1),
        onSelect: @escaping () -> Void
    ) {
        self.game = game
        self.cornerRadius = cornerRadius
        self.gameCoverTitlePoints = gameCoverTitlePoints
        self.borderStrokeColor = borderStrokeColor
        self.onSelect = onSelect
    }

    private var primaryURL: URL? {
        game.gifCover ?? game.iconUrl
    }

    private var secondaryURL: URL? {
        (game.gifCover != nil) ? game.iconUrl : nil
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                Color.white.opacity(0.06)

                coverVisual
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.95), location: 0),
                        .init(color: .black.opacity(0.45), location: 0.25),
                        .init(color: .black.opacity(0), location: 0.48),
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

                Text(game.name)
                    .font(.system(size: gameCoverTitlePoints, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.65), radius: 12, x: 0, y: 10)
                    .padding(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderStrokeColor, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Play \(game.name)"))
    }

    @ViewBuilder
    private var coverVisual: some View {
        Group {
            switch imageStage {
            case .primary:
                if game.gifCover != nil, let url = primaryURL {
                    RemoteUIImageCover(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let url = primaryURL {
                    AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .failure:
                            Color.clear.onAppear { advanceStage() }
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .tint(.white.opacity(0.4))
                        @unknown default:
                            Color.clear
                        }
                    }
                } else {
                    fallbackEmojiCanvas
                }
            case .iconOnly:
                if let url = secondaryURL {
                    AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .failure:
                            Color.clear.onAppear { advanceStage() }
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .tint(.white.opacity(0.4))
                        @unknown default:
                            Color.clear
                        }
                    }
                } else {
                    fallbackEmojiCanvas
                }
            case .fallbackEmoji:
                fallbackEmojiCanvas
            }
        }
    }

    private var fallbackEmojiCanvas: some View {
        Color.white.opacity(0.04)
            .overlay(
                Text(game.iconFallback ?? fallbackEmoji)
                    .font(.system(size: 48))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fallbackEmoji: String {
        let h = abs(game.id.hashValue)
        return fallbackEmojis[h % fallbackEmojis.count]
    }

    private func advanceStage() {
        switch imageStage {
        case .primary:
            if secondaryURL != nil {
                imageStage = .iconOnly
            } else {
                imageStage = .fallbackEmoji
            }
        case .iconOnly:
            imageStage = .fallbackEmoji
        case .fallbackEmoji:
            break
        }
    }
}
