import SwiftUI

private let desktopPageSize = 4

/// Four-column **`LazyVGrid`** with dot / arrow / text pagination mirroring desktop `GameGrid` in React.
struct MiniGameTabletGridView: View {
    let games: [GameData]
    let theme: MiniGameTheme
    let navigationKind: MiniGameNavigationKind
    let onSelect: (GameData) -> Void

    @State private var currentPage: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { outer in
                let totalPages = Self.pageCount(for: games.count)
                let slice = Self.games(forPage: currentPage, in: games)

                let (cardWidth, cardHeight) = Self.portraitCoverDimensions(bounds: outer.size)

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(minimum: 140, maximum: .infinity), spacing: 24, alignment: .center),
                        count: 4
                    ),
                    alignment: .center,
                    spacing: 24
                ) {
                    ForEach(slice, id: \.id) { game in
                        GameCoverCardView(game: game, borderStrokeColor: theme.cardHighlightStrokeColor) {
                            onSelect(game)
                        }
                        .frame(width: cardWidth, height: cardHeight)
                    }
                    if slice.count < desktopPageSize {
                        ForEach(0..<(desktopPageSize - slice.count), id: \.self) { _ in
                            Color.clear
                                .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .animation(.easeOut(duration: 0.25), value: currentPage)
                .contentShape(Rectangle())
                .gesture(pageSwipeGesture(totalPages: totalPages))
                .onChange(of: totalPages) { newTotal in
                    if currentPage >= newTotal, newTotal > 0 {
                        currentPage = newTotal - 1
                    }
                }
            }

            paginationRow
                .frame(minHeight: 50)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var paginationRow: some View {
        let totalPages = Self.pageCount(for: games.count)
        if totalPages > 1 {
            switch navigationKind {
            case .dot:
                dotRow(totalPages: totalPages)
            case .arrow:
                arrowRow(totalPages: totalPages)
            case .pagination:
                textRow(totalPages: totalPages)
            }
        } else {
            Color.clear.frame(height: 0)
        }
    }

    private func dotRow(totalPages: Int) -> some View {
        let dots = visibleDots(current: currentPage, total: totalPages)
        return HStack(spacing: 12) {
            ForEach(dots, id: \.pageIndex) { dot in
                Button {
                    goToPage(dot.pageIndex, totalPages: totalPages)
                } label: {
                    let size = dotSize(page: dot.pageIndex, current: currentPage)
                    let opacity = dotOpacity(page: dot.pageIndex, current: currentPage)
                    Circle()
                        .fill(theme.accentColor.opacity(opacity))
                        .frame(width: size, height: size)
                        // iPad: tiny circles miss taps and hit the scrim behind the sheet.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Page \(dot.pageIndex + 1) of \(totalPages)"))
            }
        }
    }

    private func arrowRow(totalPages: Int) -> some View {
        HStack(spacing: 12) {
            circleNavButton(disabled: currentPage == 0) {
                goToPage(currentPage - 1, totalPages: totalPages)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
            }
            .accessibilityLabel(Text("Previous page"))

            circleNavButton(disabled: currentPage >= totalPages - 1) {
                goToPage(currentPage + 1, totalPages: totalPages)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
            }
            .accessibilityLabel(Text("Next page"))
        }
    }

    private func textRow(totalPages: Int) -> some View {
        HStack(spacing: 14) {
            circleNavButton(disabled: currentPage == 0, extraWidth: true) {
                goToPage(currentPage - 1, totalPages: totalPages)
            } label: {
                Text("Prev")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.accentColor)
            }
            Text("\(currentPage + 1) / \(totalPages)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.secondaryFontColor)
            circleNavButton(disabled: currentPage >= totalPages - 1, extraWidth: true) {
                goToPage(currentPage + 1, totalPages: totalPages)
            } label: {
                Text("Next")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.accentColor)
            }
        }
    }

    private func circleNavButton(
        disabled: Bool,
        extraWidth: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> some View
    ) -> some View {
        Button(action: action) {
            label()
                .frame(minWidth: extraWidth ? 88 : 40, minHeight: 40)
                .padding(.horizontal, extraWidth ? 14 : 0)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 0.82)
    }

    private func goToPage(_ index: Int, totalPages: Int) {
        guard index >= 0, index < totalPages, index != currentPage else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            currentPage = index
        }
    }

    private func pageSwipeGesture(totalPages: Int) -> some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 50, abs(dx) > abs(dy) else { return }
                if dx < 0, currentPage < totalPages - 1 {
                    goToPage(currentPage + 1, totalPages: totalPages)
                } else if dx > 0, currentPage > 0 {
                    goToPage(currentPage - 1, totalPages: totalPages)
                }
            }
    }

    private struct DotModel: Identifiable {
        var id: Int { pageIndex }
        var pageIndex: Int
    }

    private func visibleDots(current: Int, total: Int) -> [DotModel] {
        let maxVisible = 5
        if total <= maxVisible {
            return (0..<total).map { DotModel(pageIndex: $0) }
        }
        let half = maxVisible / 2
        var start = current - half
        var end = current + half
        if start < 0 {
            start = 0
            end = maxVisible - 1
        }
        if end >= total {
            end = total - 1
            start = total - maxVisible
        }
        return (0..<maxVisible).map { DotModel(pageIndex: start + $0) }
    }

    private func dotSize(page: Int, current: Int) -> CGFloat {
        let d = abs(page - current)
        if d == 0 { return 10 }
        if d == 1 { return 8 }
        return 6
    }

    private func dotOpacity(page: Int, current: Int) -> Double {
        let d = abs(page - current)
        if d == 0 { return 1 }
        if d == 1 { return 0.5 }
        return 0.3
    }

    /// Locks each tile to **`width × height`** so flexible grid columns cannot flatten covers into strips on iPad.
    private static func portraitCoverDimensions(bounds: CGSize) -> (CGFloat, CGFloat) {
        let vw = max(4, bounds.width)
        let vh = max(4, bounds.height)
        let colSpacing: CGFloat = 24
        let cols = CGFloat(desktopPageSize)
        let interColumn = colSpacing * (cols - 1)
        let maxPortraitWidth = max(104, floor((vw - interColumn) / cols))

        var portraitH = max(352, vh * 0.52)
        var portraitW = portraitH * CarouselLayout.portraitAspect
        if portraitW > maxPortraitWidth {
            portraitW = maxPortraitWidth
            portraitH = portraitW / CarouselLayout.portraitAspect
        }

        portraitH = min(portraitH, max(352, vh * 0.88))
        portraitW = min(portraitH * CarouselLayout.portraitAspect, maxPortraitWidth)
        portraitH = portraitW / CarouselLayout.portraitAspect
        return (portraitW, portraitH)
    }

    private static func pageCount(for count: Int) -> Int {
        max(1, Int(ceil(Double(count) / Double(desktopPageSize))))
    }

    private static func games(forPage page: Int, in games: [GameData]) -> [GameData] {
        let start = page * desktopPageSize
        return Array(games.dropFirst(start).prefix(desktopPageSize))
    }
}
