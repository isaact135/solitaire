import CoreGraphics
import Foundation

struct BoardEntry: Identifiable {
    let card: Card
    let origin: CGPoint
    let zIndex: Int
    let source: CardSource?
    let isStock: Bool
    let isInteractive: Bool

    var id: String { card.id }
}

struct BoardLayout {
    static let spacingRatio: CGFloat = 0.013

    let width: CGFloat
    let cardWidth: CGFloat
    let cardSize: CGSize
    let stockFrame: CGRect
    let wasteFrame: CGRect
    let foundationFrames: [CGRect]
    let tableauFrames: [CGRect]
    let entries: [BoardEntry]
    let height: CGFloat

    /// `gutter` opens a gap between the stock side (columns 0–2) and the
    /// foundation side (columns 3–6), so a fold can run between them.
    /// Tableau columns close up their fans to stay within `maxHeight`.
    init(game: GameSnapshot, width: CGFloat, gutter: CGFloat = 0, maxHeight: CGFloat = .infinity) {
        self.width = width

        let cardsWidth = max(0, width - gutter)
        let spacing = max(2, min(12, cardsWidth * Self.spacingRatio))
        let cardWidth = Self.cardWidth(forWidth: cardsWidth)
        let cardHeight = cardWidth * 1.4
        let cardSize = CGSize(width: cardWidth, height: cardHeight)
        let rowWidth = cardWidth * 7 + spacing * 6 + gutter
        let startX = max(0, (width - rowWidth) / 2)
        let tableauY = cardHeight + max(18, cardWidth * 0.22)
        let downOffset = max(7, cardWidth * 0.13)
        // Covered face-up cards show their rank and suit when there's room,
        // and just their rank when a column has to close up.
        let roomyUpOffset = max(14, cardWidth * 0.46)
        let tightUpOffset = max(14, cardWidth * 0.28)
        let fanOffset = max(7, cardWidth * 0.18)

        self.cardWidth = cardWidth
        self.cardSize = cardSize

        func x(for column: Int) -> CGFloat {
            startX + CGFloat(column) * (cardWidth + spacing) + (column > 2 ? gutter : 0)
        }

        stockFrame = CGRect(origin: CGPoint(x: x(for: 0), y: 0), size: cardSize)
        wasteFrame = CGRect(origin: CGPoint(x: x(for: 1), y: 0), size: cardSize)
        foundationFrames = (3...6).map {
            CGRect(origin: CGPoint(x: x(for: $0), y: 0), size: cardSize)
        }

        var entries: [BoardEntry] = []
        var tableauFrames: [CGRect] = []
        var maximumTableauHeight = cardHeight

        let visibleStock = game.stock.suffix(3)
        for (offset, card) in visibleStock.enumerated() {
            entries.append(BoardEntry(
                card: card,
                origin: stockFrame.origin,
                zIndex: offset,
                source: nil,
                isStock: true,
                isInteractive: offset == visibleStock.count - 1
            ))
        }

        let fanCount = game.drawCount == .one ? 1 : min(3, game.waste.count)
        let visibleWaste = game.waste.suffix(fanCount)
        for (offset, card) in visibleWaste.enumerated() {
            let isTop = offset == visibleWaste.count - 1
            entries.append(BoardEntry(
                card: card,
                origin: CGPoint(x: wasteFrame.minX + CGFloat(offset) * fanOffset, y: 0),
                zIndex: 20 + offset,
                source: isTop ? .waste : nil,
                isStock: false,
                isInteractive: isTop
            ))
        }

        for (foundation, pile) in game.foundations.enumerated() {
            guard let card = pile.last else { continue }
            entries.append(BoardEntry(
                card: card,
                origin: foundationFrames[foundation].origin,
                zIndex: 40 + foundation,
                source: .foundation(foundation),
                isStock: false,
                isInteractive: true
            ))
        }

        for (column, pile) in game.tableau.enumerated() {
            let covered = pile.dropLast()
            let coveredDown = CGFloat(covered.filter { !$0.isFaceUp }.count)
            let coveredUp = CGFloat(covered.count) - coveredDown
            let room = maxHeight - tableauY - cardHeight - coveredDown * downOffset
            let upOffset = coveredUp > 0
                ? min(roomyUpOffset, max(tightUpOffset, room / coveredUp))
                : roomyUpOffset
            var yOffset: CGFloat = 0
            for (index, card) in pile.enumerated() {
                let isTop = index == pile.count - 1
                entries.append(BoardEntry(
                    card: card,
                    origin: CGPoint(x: x(for: column), y: tableauY + yOffset),
                    zIndex: 100 + column * 30 + index,
                    source: .tableau(column: column, index: index),
                    isStock: false,
                    isInteractive: isTop || Self.isValidRun(Array(pile[index...]))
                ))
                yOffset += card.isFaceUp ? upOffset : downOffset
            }

            let pileHeight = pile.isEmpty ? cardHeight : yOffset - (pile.last?.isFaceUp == true ? upOffset : downOffset) + cardHeight
            maximumTableauHeight = max(maximumTableauHeight, pileHeight)
            tableauFrames.append(CGRect(
                x: x(for: column),
                y: tableauY,
                width: cardWidth,
                height: pileHeight
            ))
        }

        self.tableauFrames = tableauFrames
        self.entries = entries
        self.height = tableauY + maximumTableauHeight + 4
    }

    /// The board width, without a gutter, whose cards come out `cardWidth` wide.
    static func width(forCardWidth cardWidth: CGFloat) -> CGFloat {
        cardWidth * 7 / (1 - 6 * spacingRatio)
    }

    static func cardWidth(forWidth width: CGFloat) -> CGFloat {
        let spacing = max(2, min(12, width * spacingRatio))
        return min(112, max(1, (width - spacing * 6) / 7))
    }

    private static func isValidRun(_ cards: [Card]) -> Bool {
        guard let first = cards.first, first.isFaceUp else { return false }
        return cards.dropFirst().enumerated().allSatisfy { offset, card in
            let previous = cards[offset]
            return card.isFaceUp && previous.suit.isRed != card.suit.isRed
                && previous.rank == card.rank + 1
        }
    }

    func dropTarget(
        for leadFrame: CGRect,
        accepting isAccepted: (DropTarget) -> Bool = { _ in true }
    ) -> DropTarget? {
        var bestTarget: DropTarget?
        var bestArea: CGFloat = 0
        let minimumArea = leadFrame.width * leadFrame.height * 0.2

        for (index, frame) in foundationFrames.enumerated() {
            let area = leadFrame.intersection(frame).area
            if area > minimumArea && area > bestArea && isAccepted(.foundation(index)) {
                bestArea = area
                bestTarget = .foundation(index)
            }
        }

        for (index, frame) in tableauFrames.enumerated() {
            let area = leadFrame.intersection(frame).area
            if area > minimumArea && area > bestArea && isAccepted(.tableau(index)) {
                bestArea = area
                bestTarget = .tableau(index)
            }
        }
        return bestTarget
    }
}

/// Where the board sits in its container: centered, or split around a fold
/// with the stock side on one page and the foundations on the other.
struct BoardPlacement: Equatable {
    let width: CGFloat
    /// Extra space `BoardLayout` adds between the two sides of a split board.
    let gutter: CGFloat
    let originX: CGFloat
    /// Height the tableau should fit in before the board scrolls.
    let boardHeight: CGFloat
    let isSplit: Bool
    /// Widths of the stock side and the foundation side when split; a
    /// centered board is all leading side.
    let leadingWidth: CGFloat
    let trailingWidth: CGFloat

    init(containerSize: CGSize, fold: ClosedRange<CGFloat>? = nil) {
        let padding = max(12, min(24, containerSize.width * 0.025))
        // Cards are as large as the height allows for a typical mid-game
        // board; longer columns close up their fans before the board scrolls.
        let heightLimit = max(40, containerSize.height / 5.6)
        boardHeight = max(0, containerSize.height - 64)

        if let fold,
           fold.lowerBound - padding > 0,
           containerSize.width - padding - fold.upperBound > 0 {
            let spacingPerCard = BoardLayout.width(forCardWidth: 1) * BoardLayout.spacingRatio
            let leadingPerCard = 3 + 2 * spacingPerCard
            let trailingPerCard = 4 + 3 * spacingPerCard
            let cardWidth = min(
                112,
                heightLimit,
                (fold.lowerBound - padding) / leadingPerCard,
                (containerSize.width - padding - fold.upperBound) / trailingPerCard
            )
            // The columns either side of the gutter already sit one spacing apart.
            gutter = max(0, fold.upperBound - fold.lowerBound - cardWidth * spacingPerCard)
            width = BoardLayout.width(forCardWidth: cardWidth) + gutter
            leadingWidth = cardWidth * leadingPerCard
            trailingWidth = cardWidth * trailingPerCard
            originX = fold.lowerBound - leadingWidth
            isSplit = true
        } else {
            let available = max(0, containerSize.width - padding * 2)
            gutter = 0
            width = min(1_040, available, BoardLayout.width(forCardWidth: min(112, heightLimit)))
            leadingWidth = width
            trailingWidth = 0
            originX = (containerSize.width - width) / 2
            isSplit = false
        }
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isInfinite else { return 0 }
        return max(0, width) * max(0, height)
    }
}
