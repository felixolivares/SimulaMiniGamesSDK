import SwiftUI

/// Shared metrics for the phone carousel strip.
enum CarouselLayout {
    static let carouselCardGap: CGFloat = 12
    /// Used with `predictedEndTranslation` distance (pts) to treat a drag as a fast flick.
    static let carouselVelocityProjectionFactor: CGFloat = 22
    /// Extra predicted travel beyond current translation crosses this → classify as flick (one-column cap).
    static let carouselPredictedStretchThreshold: CGFloat = 55
    static let portraitAspect: CGFloat = 9.0 / 16.0
    /// Neighbors render smaller while off-center, matching RN `MobileCarousel` depth (~0.85–0.92).
    static let neighborVisualScale: CGFloat = 0.86
    static let verticalCardBleed: CGFloat = 22
    static let headerToCarouselSpacing: CGFloat = 14

    static func carouselStripCap(from proposal: CGFloat) -> CGFloat {
        min(max(proposal * 0.62, 352), 640)
    }

    static func portraitCardHeight(stripCap: CGFloat) -> CGFloat {
        max(352, stripCap * 0.78)
    }
}

/// Carousel for `.compact` width — peeking neighbours, scroll‑snap centre, neighbour scale, **`3 × N`** infinite strip.
struct MiniGamePhoneCarouselView: View {
    let games: [GameData]
    let cardBorderStrokeColor: Color
    let onSelect: (GameData) -> Void

    init(
        games: [GameData],
        cardBorderStrokeColor: Color = Color(red: 120 / 255, green: 200 / 255, blue: 255 / 255).opacity(0.1),
        onSelect: @escaping (GameData) -> Void
    ) {
        self.games = games
        self.cardBorderStrokeColor = cardBorderStrokeColor
        self.onSelect = onSelect
    }

    var body: some View {
        GeometryReader { geo in
            let stripCap = CarouselLayout.carouselStripCap(from: geo.size.height)
            let cardHeight = CarouselLayout.portraitCardHeight(stripCap: stripCap)
            let cardWidth = cardHeight * CarouselLayout.portraitAspect
            let viewportWidth = geo.size.width
            let horizontalInset = max(6, viewportWidth * 0.028)

            Group {
                if games.count == 1, let sole = games.first {
                    soloCard(
                        sole,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        viewportWidth: viewportWidth - horizontalInset * 2
                    )
                } else if games.count > 1 {
                    snapCarousel(
                        games: games,
                        viewportWidth: viewportWidth - horizontalInset * 2,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight
                    )
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, horizontalInset)
            .padding(.top, CarouselLayout.headerToCarouselSpacing)
        }
    }

    private func totalRowHeight(cardHeight: CGFloat) -> CGFloat {
        cardHeight + CarouselLayout.verticalCardBleed * 2
    }

    private func soloCard(_ game: GameData, cardWidth: CGFloat, cardHeight: CGFloat, viewportWidth: CGFloat) -> some View {
        GameCoverCardView(game: game, borderStrokeColor: cardBorderStrokeColor) {
            onSelect(game)
        }
        .frame(width: cardWidth, height: cardHeight)
        .padding(.vertical, CarouselLayout.verticalCardBleed)
        .frame(width: viewportWidth)
    }

    private func snapCarousel(
        games: [GameData],
        viewportWidth: CGFloat,
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        let rowH = totalRowHeight(cardHeight: cardHeight)
        return MiniGameInfiniteCoverCarousel(
            games: games,
            cardBorderStrokeColor: cardBorderStrokeColor,
            viewportWidth: max(8, viewportWidth),
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            rowHeight: rowH,
            cardGap: CarouselLayout.carouselCardGap,
            onSelect: onSelect
        )
        .frame(width: max(8, viewportWidth), height: rowH)
    }
}

// MARK: - RN `MobileCarousel`-style triple strip

private struct MiniGameInfiniteCoverCarousel: View {
    let games: [GameData]
    let cardBorderStrokeColor: Color
    let viewportWidth: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let rowHeight: CGFloat
    let cardGap: CGFloat
    let onSelect: (GameData) -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var hasSyncedInitialOffset = false
    @State private var isDragging = false
    @State private var dragStartScrollOffset: CGFloat = 0
    @State private var dragStartPhysical: Int = 0
    /// After a carousel drag, finger-up often still activates `GameCoverCardView`’s `Button`; blocks stray taps briefly.
    @State private var suppressCardSelection: Bool = false

    private var gap: CGFloat { cardGap }
    private var slot: CGFloat { cardWidth + gap }
    private var sideInset: CGFloat { max(0, (viewportWidth - cardWidth) / 2) }

    private var gamesSignature: String {
        games.map(\.id).joined(separator: "|")
    }

    private struct LoopTile: Identifiable {
        let id: String
        let physicalIndex: Int
        let game: GameData
    }

    private var tiles: [LoopTile] {
        let n = games.count
        guard n > 0 else { return [] }
        return (0 ..< 3).flatMap { copy in
            games.enumerated().map { idx, game in
                let physical = copy * n + idx
                return LoopTile(id: "\(physical)-\(game.id)", physicalIndex: physical, game: game)
            }
        }
    }

    private func settledPhysical(_ physical: Int) -> CGFloat {
        let centerX = sideInset + CGFloat(physical) * slot + cardWidth / 2
        return viewportWidth / 2 - centerX
    }

    private func clampedOffset(_ x: CGFloat) -> CGFloat {
        let n = games.count
        guard n > 1 else { return settledPhysical(0) }
        let lo = settledPhysical(3 * n - 1)
        let hi = settledPhysical(0)
        return min(max(x, lo), hi)
    }

    private func nearestPhysical(toOffset offset: CGFloat) -> Int {
        let n = games.count
        var best = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for p in 0 ..< (3 * n) {
            let d = abs(offset - settledPhysical(p))
            if d < bestDist {
                bestDist = d
                best = p
            }
        }
        return best
    }

    private func effectiveViewportWidthForScale() -> CGFloat {
        viewportWidth > 8 ? viewportWidth : max(200, cardWidth + sideInset * 2)
    }

    private func scale(forPhysicalIndex physical: Int) -> CGFloat {
        let minS = CarouselLayout.neighborVisualScale
        let cardMid = sideInset + CGFloat(physical) * slot + cardWidth / 2 + scrollOffset
        let vpMid = effectiveViewportWidthForScale() / 2
        let normalized = abs(cardMid - vpMid) / max(slot, 1)
        let focused = max(0, min(1, 1 - normalized))
        return minS + (1 - minS) * focused
    }

    private func snapSpring() -> Animation {
        .interpolatingSpring(stiffness: 290, damping: 29)
    }

    private func resolveSnapTargetPhysical(after gesture: DragGesture.Value) -> Int {
        let n = games.count
        let travelDeltaW = gesture.predictedEndTranslation.width - gesture.translation.width
        let travelDeltaH = gesture.predictedEndTranslation.height - gesture.translation.height
        let projectedStretch = hypot(travelDeltaW, travelDeltaH)
        let projectedOffset = clampedOffset(
            dragStartScrollOffset + gesture.translation.width + travelDeltaW * CarouselLayout.carouselVelocityProjectionFactor / 220
        )

        var target = nearestPhysical(toOffset: projectedOffset)
        let fast = projectedStretch >= CarouselLayout.carouselPredictedStretchThreshold
        if fast {
            target = min(max(target, dragStartPhysical - 1), dragStartPhysical + 1)
            target = min(max(target, 0), 3 * n - 1)
        }
        return target
    }

    private func applyInfiniteWrapIfNeeded(afterLandingOn targetPhysical: Int) {
        let n = games.count
        guard n > 1 else { return }

        Task { @MainActor in
            let destination: CGFloat?
            if targetPhysical < n {
                destination = settledPhysical(targetPhysical + n)
            } else if targetPhysical >= 2 * n {
                destination = settledPhysical(targetPhysical - n)
            } else {
                destination = nil
            }
            guard let destination else { return }
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                scrollOffset = clampedOffset(destination)
            }
        }
    }

    private func scheduleCardSelectionSuppressionReset() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            suppressCardSelection = false
        }
    }

    var body: some View {
        let drag = DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard abs(value.translation.width) >= abs(value.translation.height) * 0.55 else { return }

                if !isDragging {
                    isDragging = true
                    dragStartScrollOffset = scrollOffset
                    dragStartPhysical = nearestPhysical(toOffset: scrollOffset)
                    suppressCardSelection = true
                }
                scrollOffset = clampedOffset(dragStartScrollOffset + value.translation.width)
            }
            .onEnded { value in
                defer { isDragging = false }
                if suppressCardSelection {
                    scheduleCardSelectionSuppressionReset()
                }
                guard games.count > 1 else { return }
                guard isDragging || abs(value.translation.width) >= 14 else { return }
                guard abs(value.translation.width) >= abs(value.translation.height) * 0.55 else { return }

                let targetPhysical = resolveSnapTargetPhysical(after: value)
                withAnimation(snapSpring()) {
                    scrollOffset = settledPhysical(targetPhysical)
                }
                applyInfiniteWrapIfNeeded(afterLandingOn: targetPhysical)
            }

        HStack(spacing: gap) {
            ForEach(tiles) { tile in
                GameCoverCardView(game: tile.game, borderStrokeColor: cardBorderStrokeColor) {
                    guard !suppressCardSelection else { return }
                    onSelect(tile.game)
                }
                .frame(width: cardWidth, height: cardHeight)
                .padding(.vertical, CarouselLayout.verticalCardBleed)
                .scaleEffect(scale(forPhysicalIndex: tile.physicalIndex))
            }
        }
        .padding(.horizontal, sideInset)
        .offset(x: scrollOffset)
        .frame(width: viewportWidth, height: rowHeight, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(drag)
        .onAppear {
            guard viewportWidth > 8, games.count > 1 else { return }
            if !hasSyncedInitialOffset {
                scrollOffset = settledPhysical(games.count)
                hasSyncedInitialOffset = true
            }
        }
        .onChange(of: gamesSignature) { _ in
            guard viewportWidth > 8, games.count > 1 else { return }
            scrollOffset = settledPhysical(games.count)
        }
        .onChange(of: viewportWidth) { _ in
            guard viewportWidth > 8, games.count > 1 else { return }
            let logical = nearestPhysical(toOffset: scrollOffset) % games.count
            scrollOffset = clampedOffset(settledPhysical(games.count + logical))
        }
    }
}
