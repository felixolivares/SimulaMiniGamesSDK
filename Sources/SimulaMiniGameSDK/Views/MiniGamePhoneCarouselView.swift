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

/// Carousel for `.compact` width — peeking neighbors, scroll‑snap centre, neighbour scale; **pure SwiftUI** (no bridging).
struct MiniGamePhoneCarouselView: View {
    let games: [GameData]
    let onSelect: (GameData) -> Void

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
        GameCoverCardView(game: game) {
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
        return MiniGamePhoneSnapCarousel(
            games: games,
            viewportWidth: max(8, viewportWidth),
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            rowHeight: rowH,
            onSelect: onSelect
        )
        .frame(width: max(8, viewportWidth), height: rowH)
    }
}

// MARK: - Pure SwiftUI snap carousel

private struct MiniGamePhoneSnapCarousel: View {
    let games: [GameData]
    let viewportWidth: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let rowHeight: CGFloat
    let onSelect: (GameData) -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var hasSyncedInitialOffset = false
    @State private var isDragging = false
    @State private var dragStartScrollOffset: CGFloat = 0
    @State private var dragStartIndex: Int = 0
    /// After a carousel drag, finger-up often still activates `GameCoverCardView`’s `Button`, which dismissed the modal via `handleSelect`; blocks that stray action briefly.
    @State private var suppressCardSelection: Bool = false

    private var gap: CGFloat { CarouselLayout.carouselCardGap }
    private var slot: CGFloat { cardWidth + gap }
    private var sideInset: CGFloat { max(0, (viewportWidth - cardWidth) / 2) }

    private var gamesSignature: String {
        games.map(\.id).joined(separator: "|")
    }

    private func settledOffset(forIndex index: Int) -> CGFloat {
        let centerX = sideInset + CGFloat(index) * slot + cardWidth / 2
        return viewportWidth / 2 - centerX
    }

    private func clampedOffset(_ x: CGFloat) -> CGFloat {
        let n = games.count
        guard n > 1 else { return settledOffset(forIndex: 0) }
        let lo = settledOffset(forIndex: n - 1)
        let hi = settledOffset(forIndex: 0)
        return min(max(x, lo), hi)
    }

    private func nearestIndex(toOffset offset: CGFloat) -> Int {
        let n = games.count
        var best = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for i in 0..<n {
            let d = abs(offset - settledOffset(forIndex: i))
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return best
    }

    private func effectiveViewportWidthForScale() -> CGFloat {
        viewportWidth > 8 ? viewportWidth : max(200, cardWidth + sideInset * 2)
    }

    private func scale(forCardIndex index: Int) -> CGFloat {
        let minS = CarouselLayout.neighborVisualScale
        let cardMid = sideInset + CGFloat(index) * slot + cardWidth / 2 + scrollOffset
        let vpMid = effectiveViewportWidthForScale() / 2
        let normalized = abs(cardMid - vpMid) / max(slot, 1)
        let focused = max(0, min(1, 1 - normalized))
        return minS + (1 - minS) * focused
    }

    private func snapSpring() -> Animation {
        .interpolatingSpring(stiffness: 290, damping: 29)
    }

    /// Projects predicted travel from the drag gesture, then clamps fast flicks to one column.
    private func resolveSnapTarget(after gesture: DragGesture.Value) -> Int {
        let n = games.count
        let travelDeltaW = gesture.predictedEndTranslation.width - gesture.translation.width
        let travelDeltaH = gesture.predictedEndTranslation.height - gesture.translation.height
        let projectedStretch = hypot(travelDeltaW, travelDeltaH)
        let projectedOffset = clampedOffset(
            dragStartScrollOffset + gesture.translation.width + travelDeltaW * CarouselLayout.carouselVelocityProjectionFactor / 220
        )

        var target = nearestIndex(toOffset: projectedOffset)
        let fast = projectedStretch >= CarouselLayout.carouselPredictedStretchThreshold
        if fast {
            target = min(max(target, dragStartIndex - 1), dragStartIndex + 1)
            target = min(max(target, 0), n - 1)
        }
        return target
    }

    private func scheduleCardSelectionSuppressionReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
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
                    dragStartIndex = nearestIndex(toOffset: scrollOffset)
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

                let targetIdx = resolveSnapTarget(after: value)
                withAnimation(snapSpring()) {
                    scrollOffset = settledOffset(forIndex: targetIdx)
                }
            }

        HStack(spacing: gap) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                GameCoverCardView(game: game) {
                    guard !suppressCardSelection else { return }
                    onSelect(game)
                }
                .frame(width: cardWidth, height: cardHeight)
                .padding(.vertical, CarouselLayout.verticalCardBleed)
                .scaleEffect(scale(forCardIndex: index))
            }
        }
        .padding(.horizontal, sideInset)
        .offset(x: scrollOffset)
        .frame(width: viewportWidth, height: rowHeight, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(drag)
        .onAppear {
            guard viewportWidth > 8 else { return }
            if !hasSyncedInitialOffset {
                scrollOffset = settledOffset(forIndex: 0)
                hasSyncedInitialOffset = true
            }
        }
        .onChange(of: gamesSignature) { _ in
            guard viewportWidth > 8 else { return }
            let idx = min(max(nearestIndex(toOffset: scrollOffset), 0), games.count - 1)
            scrollOffset = settledOffset(forIndex: idx)
        }
        .onChange(of: viewportWidth) { _ in
            guard viewportWidth > 8 else { return }
            let idx = min(max(nearestIndex(toOffset: scrollOffset), 0), games.count - 1)
            scrollOffset = settledOffset(forIndex: idx)
        }
    }
}
