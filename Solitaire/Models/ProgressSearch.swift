import Foundation

extension GameSnapshot {
    /// Whether some sequence of moves can still turn over a hidden card, play a
    /// card from the deck, or clear the board. Moves that only rearrange face-up
    /// cards don't count on their own, so a game that can only go in circles is
    /// stuck. The search answers true if it gives up, after visiting `limit`
    /// positions or when its task is cancelled.
    func canMakeProgress(limit: Int = 100_000) -> Bool {
        ProgressSearch(self).canMakeProgress(limit: limit)
    }

    /// The cards drawing can bring to the top of the waste. Until a card leaves
    /// the deck, every pass after a recycle draws the same cards.
    fileprivate func reachableDeckCards() -> [Card] {
        var cards = Array(waste.suffix(1))
        var stock = self.stock
        var waste = self.waste
        for _ in 0..<2 {
            while !stock.isEmpty {
                for _ in 0..<drawCount.rawValue where !stock.isEmpty {
                    waste.append(stock.removeLast())
                }
                cards.append(waste[waste.count - 1])
            }
            while let card = waste.popLast() {
                stock.append(card)
            }
        }
        return cards
    }
}

/// Searches the positions reachable by moving face-up cards around the tableau
/// and foundations. Turning over a card ends the search, so the hidden cards
/// under each column never change.
///
/// Each position is a flat byte array: the top rank of each suit's foundation,
/// then each column's face-up card count followed by its cards.
private struct ProgressSearch {
    private let hiddenCounts: [Int]
    /// Columns without hidden cards. Positions keep them sorted by their first
    /// card, so rearranging them doesn't make a new position.
    private let openColumns: [Int]
    private let deckCards: [UInt8]
    /// No hidden cards and an empty deck, so clearing the board wins.
    private let onlyFaceUpCardsLeft: Bool
    private let hasHiddenTopCard: Bool
    private let startColumns: [[UInt8]]
    private let startFoundations: [UInt8]

    init(_ game: GameSnapshot) {
        let hiddenCounts = game.tableau.map { pile in pile.prefix { !$0.isFaceUp }.count }
        let columns = zip(game.tableau, hiddenCounts).map { pile, hiddenCount in
            pile.dropFirst(hiddenCount).map(\.code)
        }
        var foundations: [UInt8] = [0, 0, 0, 0]
        for card in game.foundations.compactMap(\.last).map(\.code) {
            foundations[card.suit] = max(foundations[card.suit], card.rank)
        }

        self.hiddenCounts = hiddenCounts
        openColumns = hiddenCounts.indices.filter { hiddenCounts[$0] == 0 }
        deckCards = game.reachableDeckCards().map(\.code)
        onlyFaceUpCardsLeft = game.stock.isEmpty && game.waste.isEmpty && openColumns.count == hiddenCounts.count
        hasHiddenTopCard = zip(columns, hiddenCounts).contains { $0.isEmpty && $1 > 0 }
        startColumns = columns
        startFoundations = foundations
    }

    func canMakeProgress(limit: Int) -> Bool {
        if hasHiddenTopCard { return true }
        let start = encode(startColumns, startFoundations)
        var seen: Set<[UInt8]> = [start]
        var pending = [start]
        var visited = 0

        while let position = pending.popLast() {
            visited += 1
            if visited.isMultiple(of: 1_024), Task.isCancelled { return true }

            let (columns, foundations) = decode(position)
            if onlyFaceUpCardsLeft, columns.allSatisfy(\.isEmpty) { return true }
            if deckCards.contains(where: { canPlace($0, columns, foundations) }) { return true }
            guard let nextPositions = nextPositions(columns, foundations) else { return true }
            for next in nextPositions where seen.insert(next).inserted {
                guard seen.count <= limit else { return true }
                pending.append(next)
            }
        }
        return false
    }

    /// The positions one move away, or nil when a move turns over a hidden card
    /// or makes room for a deck card.
    private func nextPositions(_ columns: [[UInt8]], _ foundations: [UInt8]) -> [[UInt8]]? {
        var positions: [[UInt8]] = []
        for (from, column) in columns.enumerated() where !column.isEmpty {
            for start in runStart(column)..<column.count {
                for to in columns.indices where to != from && canStack(column[start], on: columns[to]) {
                    if start == 0, hiddenCounts[from] > 0 { return nil }
                    var next = columns
                    next[from].removeSubrange(start...)
                    next[to] += column[start...]
                    positions.append(encode(next, foundations))
                }
            }
        }

        for (suit, rank) in foundations.enumerated() where rank > 0 {
            let card = UInt8(suit << 4) | rank
            for to in columns.indices where canStack(card, on: columns[to]) {
                if bringDown(card, onto: to, columns, foundations, into: &positions) { return nil }
            }
        }

        // Added last so the search follows moves to the foundations first.
        for (from, column) in columns.enumerated() {
            guard let card = column.last, foundations[card.suit] == card.rank - 1 else { continue }
            if column.count == 1, hiddenCounts[from] > 0 { return nil }
            var next = columns
            next[from].removeLast()
            var nextFoundations = foundations
            nextFoundations[card.suit] = card.rank
            positions.append(encode(next, nextFoundations))
        }
        return positions
    }

    /// Brings a card down from its foundation and adds the positions where
    /// something then covers it: a run from another column, or a card from
    /// another foundation. Its suit's next card can also come down after it,
    /// to be covered in turn. Bringing a card down for anything else never
    /// helps, and any useful one can wait until just before it's covered.
    /// Answers true when covering it turns over a hidden card or plays a deck card.
    private func bringDown(
        _ card: UInt8,
        onto column: Int,
        _ columns: [[UInt8]],
        _ foundations: [UInt8],
        into positions: inout [[UInt8]]
    ) -> Bool {
        var columns = columns
        columns[column].append(card)
        var foundations = foundations
        foundations[card.suit] = card.rank - 1

        if deckCards.contains(where: { canStack($0, on: columns[column]) }) { return true }

        for (from, source) in columns.enumerated() where from != column && !source.isEmpty {
            for start in runStart(source)..<source.count where canStack(source[start], on: columns[column]) {
                if start == 0, hiddenCounts[from] > 0 { return true }
                var next = columns
                next[from].removeSubrange(start...)
                next[column] += source[start...]
                positions.append(encode(next, foundations))
            }
        }

        for (suit, rank) in foundations.enumerated() where rank > 0 {
            let nextCard = UInt8(suit << 4) | rank
            for to in columns.indices where canStack(nextCard, on: columns[to]) && (to == column || suit == card.suit) {
                if bringDown(nextCard, onto: to, columns, foundations, into: &positions) { return true }
            }
        }
        return false
    }

    private func canPlace(_ card: UInt8, _ columns: [[UInt8]], _ foundations: [UInt8]) -> Bool {
        foundations[card.suit] == card.rank - 1 || columns.contains { canStack(card, on: $0) }
    }

    private func canStack(_ card: UInt8, on column: [UInt8]) -> Bool {
        guard let top = column.last else { return card.rank == 13 }
        return top.isRed != card.isRed && top.rank == card.rank + 1
    }

    /// Where the longest movable run starts. Each card above it starts a shorter one.
    private func runStart(_ column: [UInt8]) -> Int {
        var start = column.count - 1
        while start > 0, column[start - 1].isRed != column[start].isRed,
              column[start - 1].rank == column[start].rank + 1 {
            start -= 1
        }
        return start
    }

    private func encode(_ columns: [[UInt8]], _ foundations: [UInt8]) -> [UInt8] {
        var columns = columns
        // A move changes at most two columns, so an insertion sort is quick.
        for index in openColumns.indices.dropFirst() {
            var slot = index
            while slot > 0, (columns[openColumns[slot]].first ?? .max) < (columns[openColumns[slot - 1]].first ?? .max) {
                columns.swapAt(openColumns[slot], openColumns[slot - 1])
                slot -= 1
            }
        }

        var position = foundations
        position.reserveCapacity(foundations.count + columns.count + 52)
        for column in columns {
            position.append(UInt8(column.count))
            position += column
        }
        return position
    }

    private func decode(_ position: [UInt8]) -> (columns: [[UInt8]], foundations: [UInt8]) {
        var columns: [[UInt8]] = []
        columns.reserveCapacity(hiddenCounts.count)
        var index = 4
        while index < position.count {
            let count = Int(position[index])
            columns.append(Array(position[index + 1 ..< index + 1 + count]))
            index += 1 + count
        }
        return (columns, Array(position[..<4]))
    }
}

private extension Card {
    /// The card as one byte: its suit in the high bits and its rank in the low four.
    var code: UInt8 {
        // Red suits are odd, which `UInt8.isRed` relies on.
        let suitIndex: UInt8 = switch suit {
        case .spades: 0
        case .hearts: 1
        case .clubs: 2
        case .diamonds: 3
        }
        return suitIndex << 4 | UInt8(rank)
    }
}

/// Reading a card byte made by `Card.code`.
private extension UInt8 {
    var suit: Int { Int(self >> 4) }
    var rank: UInt8 { self & 0x0F }
    var isRed: Bool { self & 0x10 != 0 }
}
