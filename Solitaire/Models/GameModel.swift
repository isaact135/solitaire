import Foundation
import Observation

@MainActor
@Observable
final class GameModel {
    private struct PersistedGame: Codable {
        var current: GameSnapshot
        var history: [GameSnapshot]
    }

    private nonisolated static let saveKey = "klondike.native.save.v1"
    private static let historyLimit = 400

    private(set) var game = GameSnapshot()
    private var history: [GameSnapshot] = []
    private var startedAt: Date?
    private var saveTask: Task<Void, Never>?
    private let storesGame: Bool

    var canUndo: Bool { !history.isEmpty && !hasWon }
    var hasWon: Bool { game.foundations.reduce(0) { $0 + $1.count } == 52 }
    var isStuck: Bool { !hasWon && !game.canMakeProgress() }
    var hasStarted: Bool { game.moves > 0 || game.elapsed > 0 }

    init(loadSaved: Bool = true) {
        storesGame = loadSaved

        if loadSaved, restore() {
            resume()
        } else {
            newGame()
        }
    }

    init(snapshot: GameSnapshot) {
        storesGame = false
        game = snapshot
    }

    func elapsed(at date: Date = .now) -> TimeInterval {
        guard let startedAt else { return game.elapsed }
        return game.elapsed + max(0, date.timeIntervalSince(startedAt))
    }

    /// The score at `date`, after the time penalty. The stored score catches
    /// up with the penalty at the next move.
    func score(at date: Date = .now) -> Int {
        scoreAfterTimePenalty(elapsed: elapsed(at: date)).score
    }

    func newGame(drawCount requestedDrawCount: DrawCount? = nil) {
        let drawCount = requestedDrawCount ?? game.drawCount
        var deck = Card.deck.shuffled()
        var tableau = Array(repeating: [Card](), count: 7)

        for column in 0..<7 {
            for row in 0...column {
                var card = deck.removeLast()
                card.isFaceUp = row == column
                tableau[column].append(card)
            }
        }

        game = GameSnapshot(
            stock: deck,
            waste: [],
            foundations: [[], [], [], []],
            tableau: tableau,
            drawCount: drawCount,
            score: 0,
            moves: 0,
            elapsed: 0
        )
        history.removeAll()
        startedAt = nil
        persist()
    }

    func pause() {
        guard let startedAt else {
            persist(after: .zero)
            return
        }
        game.elapsed += max(0, Date.now.timeIntervalSince(startedAt))
        self.startedAt = nil
        persist(after: .zero)
    }

    func resume() {
        guard startedAt == nil, hasStarted, !hasWon else { return }
        startedAt = .now
    }

    func drawFromStock() {
        guard !hasWon, !game.stock.isEmpty || !game.waste.isEmpty else { return }
        pushHistory()
        startTimer()
        chargeTimePenalty()

        if game.stock.isEmpty {
            while let card = game.waste.popLast() {
                var faceDownCard = card
                faceDownCard.isFaceUp = false
                game.stock.append(faceDownCard)
            }
            game.recycles += 1
            let penalty = Scoring.recyclePenalty(forRecycle: game.recycles, drawCount: game.drawCount)
            game.score = max(0, game.score - penalty)
        } else {
            for _ in 0..<game.drawCount.rawValue where !game.stock.isEmpty {
                var card = game.stock.removeLast()
                card.isFaceUp = true
                game.waste.append(card)
            }
        }

        game.moves += 1
        finishMutation()
    }

    func draggableCards(from source: CardSource) -> [Card] {
        switch source {
        case .waste:
            guard let card = game.waste.last else { return [] }
            return [card]
        case let .foundation(index):
            guard game.foundations.indices.contains(index),
                  let card = game.foundations[index].last else { return [] }
            return [card]
        case let .tableau(column, index):
            guard game.tableau.indices.contains(column) else { return [] }
            let pile = game.tableau[column]
            guard pile.indices.contains(index), pile[index].isFaceUp else { return [] }
            let cards = Array(pile[index...])
            return isValidRun(cards) ? cards : []
        }
    }

    func canMove(from source: CardSource, to target: DropTarget) -> Bool {
        let cards = draggableCards(from: source)
        guard let lead = cards.first else { return false }

        switch target {
        case let .foundation(index):
            guard game.foundations.indices.contains(index), cards.count == 1 else { return false }
            if case .foundation = source { return false }
            return canPlaceOnFoundation(lead, pile: game.foundations[index])
        case let .tableau(column):
            guard game.tableau.indices.contains(column) else { return false }
            if case let .tableau(sourceColumn, _) = source, sourceColumn == column { return false }
            return canPlaceOnTableau(lead, pile: game.tableau[column])
        }
    }

    @discardableResult
    func move(from source: CardSource, to target: DropTarget) -> Bool {
        guard !hasWon, canMove(from: source, to: target) else { return false }
        let cards = draggableCards(from: source)
        pushHistory()
        startTimer()
        chargeTimePenalty()

        switch source {
        case .waste:
            game.waste.removeLast()
        case let .foundation(index):
            game.foundations[index].removeLast()
        case let .tableau(column, index):
            game.tableau[column].removeSubrange(index...)
        }

        switch target {
        case let .foundation(index):
            game.foundations[index].append(contentsOf: cards)
        case let .tableau(column):
            game.tableau[column].append(contentsOf: cards)
        }

        if case let .tableau(column, _) = source,
           let lastIndex = game.tableau[column].indices.last,
           !game.tableau[column][lastIndex].isFaceUp {
            game.tableau[column][lastIndex].isFaceUp = true
            game.score += Scoring.turnOver
        }

        if case .foundation = source {
            game.score += Scoring.foundationToTableau
        } else if case .foundation = target {
            game.score += Scoring.toFoundation
        } else if case .waste = source {
            game.score += Scoring.wasteToTableau
        }

        game.score = max(0, game.score)
        game.moves += 1
        finishMutation()
        return true
    }

    func smartMove(from source: CardSource) {
        guard !hasWon else { return }

        if case let .tableau(column, index) = source,
           game.tableau.indices.contains(column) {
            let pile = game.tableau[column]
            if pile.indices.contains(index), index == pile.count - 1, !pile[index].isFaceUp {
                pushHistory()
                startTimer()
                chargeTimePenalty()
                game.tableau[column][index].isFaceUp = true
                game.score += Scoring.turnOver
                game.moves += 1
                finishMutation()
                return
            }
        }

        let cards = draggableCards(from: source)
        guard let lead = cards.first else { return }

        if cards.count == 1 {
            if case .foundation = source {
                // Foundation cards can only return to the tableau.
            } else {
                for index in game.foundations.indices {
                    let target = DropTarget.foundation(index)
                    if canMove(from: source, to: target) {
                        move(from: source, to: target)
                        return
                    }
                }
            }
        }

        guard lead.rank > 0 else { return }
        for column in game.tableau.indices {
            let target = DropTarget.tableau(column)
            if canMove(from: source, to: target) {
                move(from: source, to: target)
                return
            }
        }
    }

    func undo() {
        guard canUndo, let snapshot = history.popLast() else { return }
        // Undo restores the cards, not the clock.
        let time = elapsed()
        game = snapshot
        game.elapsed = time
        startedAt = nil
        resume()
        persist()
    }

    /// The same answer as `isStuck`, worked out off the main actor so a long
    /// search can't hold up the interface.
    func checkIfStuck() async -> Bool {
        guard !hasWon else { return false }
        return await Self.cannotMakeProgress(game)
    }

    @concurrent
    private nonisolated static func cannotMakeProgress(_ game: GameSnapshot) async -> Bool {
        !game.canMakeProgress()
    }

    private func startTimer() {
        guard startedAt == nil, !hasWon else { return }
        startedAt = .now
    }

    /// Takes the time penalty for play since the last charge off the stored
    /// score. Moves call this before they change the score, so the penalty
    /// applies in the right order with the score's floor of zero.
    private func chargeTimePenalty() {
        let charged = scoreAfterTimePenalty(elapsed: elapsed())
        game.score = charged.score
        game.timePenaltiesCharged = charged.periods
    }

    /// The score, and how many penalty periods it has paid for, once the
    /// penalty for `elapsed` seconds of play is taken off. The score never
    /// drops below zero.
    private func scoreAfterTimePenalty(elapsed: TimeInterval) -> (score: Int, periods: Int) {
        let periods = Int(elapsed / Scoring.timePenaltyInterval)
        let uncharged = periods - game.timePenaltiesCharged
        guard uncharged > 0 else { return (game.score, game.timePenaltiesCharged) }
        return (max(0, game.score - uncharged * Scoring.timePenalty), periods)
    }

    private func pushHistory() {
        history.append(game)
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
    }

    private func finishMutation() {
        // Only one move can win, since nothing can change a won game.
        if hasWon {
            if let startedAt {
                game.elapsed += max(0, Date.now.timeIntervalSince(startedAt))
                self.startedAt = nil
            }
            chargeTimePenalty()
            game.timeBonus = Scoring.timeBonus(elapsed: game.elapsed)
            game.score += game.timeBonus
        }
        persist()
    }

    private func canPlaceOnFoundation(_ card: Card, pile: [Card]) -> Bool {
        guard let top = pile.last else { return card.rank == 1 }
        return top.suit == card.suit && top.rank + 1 == card.rank
    }

    private func canPlaceOnTableau(_ card: Card, pile: [Card]) -> Bool {
        guard let top = pile.last else { return card.rank == 13 }
        return top.isFaceUp && top.isRed != card.isRed && top.rank == card.rank + 1
    }

    private func isValidRun(_ cards: [Card]) -> Bool {
        guard let first = cards.first, first.isFaceUp else { return false }
        return cards.dropFirst().enumerated().allSatisfy { offset, card in
            let previous = cards[offset]
            return card.isFaceUp && previous.isRed != card.isRed && previous.rank == card.rank + 1
        }
    }

    // Encoding the full undo history takes tens of milliseconds, so saves are
    // coalesced and written off the main actor, one at a time and in order.
    private func persist(after delay: Duration = .milliseconds(500)) {
        guard storesGame else { return }
        var current = game
        current.elapsed = elapsed()
        let saved = PersistedGame(current: current, history: history)
        let previous = saveTask
        previous?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: delay)
            await previous?.value
            guard !Task.isCancelled else { return }
            await Self.write(saved)
        }
    }

    @concurrent
    private nonisolated static func write(_ saved: PersistedGame) async {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func restore() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let saved = try? JSONDecoder().decode(PersistedGame.self, from: data),
              Self.isValid(saved.current) else { return false }

        game = saved.current
        history = Array(saved.history.filter(Self.isValid).suffix(Self.historyLimit))
        return true
    }

    private static func isValid(_ snapshot: GameSnapshot) -> Bool {
        let cards = snapshot.stock + snapshot.waste
            + snapshot.foundations.flatMap { $0 }
            + snapshot.tableau.flatMap { $0 }
        guard cards.count == 52, snapshot.foundations.count == 4, snapshot.tableau.count == 7 else {
            return false
        }
        return Set(cards.map(\.id)).count == 52
            && cards.allSatisfy { (1...13).contains($0.rank) }
    }
}

private extension Card {
    var isRed: Bool { suit.isRed }
}
