import CoreGraphics
import Foundation
import Testing
@testable import Solitaire

@MainActor
struct GameModelTests {
    @Test func newDealHasCorrectLayoutAndAllCards() {
        let model = GameModel(loadSaved: false)

        #expect(model.game.stock.count == 24)
        #expect(model.game.waste.isEmpty)
        #expect(model.game.foundations.allSatisfy { $0.isEmpty })
        #expect(model.game.moves == 0)
        #expect(model.game.score == 0)

        for column in 0..<7 {
            let pile = model.game.tableau[column]
            #expect(pile.count == column + 1)
            #expect(pile.dropLast().allSatisfy { !$0.isFaceUp })
            #expect(pile.last?.isFaceUp == true)
        }

        let allCards = model.game.stock + model.game.tableau.flatMap { $0 }
        #expect(allCards.count == 52)
        #expect(Set(allCards.map(\.id)).count == 52)
    }

    @Test func drawThreeAndRecyclePreserveStockOrder() {
        let stock = [
            card(.spades, 1), card(.spades, 2), card(.spades, 3), card(.spades, 4)
        ]
        let model = GameModel(snapshot: GameSnapshot(stock: stock))

        model.drawFromStock()
        #expect(model.game.waste.map(\.rank) == [4, 3, 2])
        #expect(model.game.waste.allSatisfy { $0.isFaceUp })
        #expect(model.game.moves == 1)

        model.drawFromStock()
        #expect(model.game.stock.isEmpty)
        #expect(model.game.waste.count == 4)

        model.drawFromStock()
        #expect(model.game.stock.map(\.id) == stock.map(\.id))
        #expect(model.game.stock.allSatisfy { !$0.isFaceUp })
        #expect(model.game.waste.isEmpty)
    }

    @Test func tableauMoveFlipsExposedCardAndScoresFive() {
        let hidden = card(.spades, 9, faceUp: false)
        let moving = card(.hearts, 6)
        let destination = card(.clubs, 7)
        let model = GameModel(snapshot: GameSnapshot(
            tableau: [[hidden, moving], [destination], [], [], [], [], []]
        ))

        let moved = model.move(
            from: .tableau(column: 0, index: 1),
            to: .tableau(1)
        )

        #expect(moved)
        #expect(model.game.tableau[0].map(\.id) == [hidden.id])
        #expect(model.game.tableau[0][0].isFaceUp)
        #expect(model.game.tableau[1].map(\.id) == [destination.id, moving.id])
        #expect(model.game.score == 5)
        #expect(model.game.moves == 1)
    }

    @Test func tableauRejectsSameColorAndNonKingOnEmptyPile() {
        let model = GameModel(snapshot: GameSnapshot(
            waste: [card(.hearts, 6)],
            tableau: [[card(.diamonds, 7)], [], [], [], [], [], []]
        ))

        #expect(!model.canMove(from: .waste, to: .tableau(0)))
        #expect(!model.canMove(from: .waste, to: .tableau(1)))
    }

    @Test func emptyTableauAcceptsOnlyKing() {
        let king = GameModel(snapshot: GameSnapshot(waste: [card(.clubs, 13)]))
        #expect(king.canMove(from: .waste, to: .tableau(0)))

        let queen = GameModel(snapshot: GameSnapshot(waste: [card(.clubs, 12)]))
        #expect(!queen.canMove(from: .waste, to: .tableau(0)))
    }

    @Test func foundationRequiresAscendingCardsOfOneSuit() {
        let model = GameModel(snapshot: GameSnapshot(
            waste: [card(.hearts, 2)],
            foundations: [[card(.hearts, 1)], [card(.spades, 1)], [], []]
        ))

        #expect(model.canMove(from: .waste, to: .foundation(0)))
        #expect(!model.canMove(from: .waste, to: .foundation(1)))
        #expect(!model.canMove(from: .waste, to: .foundation(2)))
    }

    @Test func foundationCardsCannotMoveToAnotherFoundation() {
        let model = GameModel(snapshot: GameSnapshot(
            foundations: [[card(.hearts, 1)], [], [], []]
        ))

        #expect(!model.canMove(from: .foundation(0), to: .foundation(0)))
        #expect(!model.canMove(from: .foundation(0), to: .foundation(1)))
    }

    @Test func smartMovePrefersFoundationOverTableau() {
        let moving = card(.hearts, 7)
        let model = GameModel(snapshot: GameSnapshot(
            waste: [moving],
            foundations: [[card(.hearts, 6)], [], [], []],
            tableau: [[card(.clubs, 8)], [], [], [], [], [], []]
        ))

        model.smartMove(from: .waste)

        #expect(model.game.waste.isEmpty)
        #expect(model.game.foundations[0].map(\.id) == [Card(suit: .hearts, rank: 6).id, moving.id])
        #expect(model.game.tableau[0].count == 1)
        #expect(model.game.score == 10)
    }

    @Test func invalidFaceUpSequenceCannotBeDragged() {
        let model = GameModel(snapshot: GameSnapshot(
            tableau: [[
                card(.clubs, 8), card(.clubs, 7), card(.hearts, 6)
            ], [], [], [], [], [], []]
        ))

        #expect(model.draggableCards(from: .tableau(column: 0, index: 0)).isEmpty)
        #expect(model.draggableCards(from: .tableau(column: 0, index: 1)).count == 2)
    }

    @Test func undoRestoresCompletePreviousPosition() {
        let model = GameModel(snapshot: GameSnapshot(
            stock: [card(.spades, 1), card(.spades, 2), card(.spades, 3)],
            score: 20
        ))
        let before = model.game

        model.drawFromStock()
        #expect(model.game != before)
        #expect(model.canUndo)

        model.undo()
        #expect(model.game.stock == before.stock)
        #expect(model.game.waste == before.waste)
        #expect(model.game.score == before.score)
        #expect(model.game.moves == before.moves)
        #expect(!model.canUndo)
    }

    @Test func undoDoesNotRewindTheClock() async throws {
        let model = GameModel(snapshot: GameSnapshot(stock: [card(.spades, 1), card(.spades, 2)]))
        #expect(!model.hasStarted)

        model.drawFromStock()
        try await Task.sleep(for: .milliseconds(150))
        model.undo()

        #expect(model.game.moves == 0)
        #expect(model.hasStarted)
        let afterUndo = model.elapsed()
        #expect(afterUndo >= 0.1)

        try await Task.sleep(for: .milliseconds(50))
        #expect(model.elapsed() > afterUndo)
    }

    @Test func movingAWholeColumnIntoAnEmptyColumnIsNotAMove() {
        let model = GameModel(snapshot: GameSnapshot(
            tableau: [[card(.spades, 13), card(.hearts, 12)], [], [], [], [], [], []]
        ))
        #expect(model.canMove(from: .tableau(column: 0, index: 0), to: .tableau(1)))
        #expect(model.isStuck)
    }

    @Test func kingCoveringHiddenCardsCanStillMoveToEmptyColumn() {
        let model = GameModel(snapshot: GameSnapshot(
            tableau: [[card(.clubs, 2, faceUp: false), card(.spades, 13)], [], [], [], [], [], []]
        ))
        #expect(!model.isStuck)
    }

    @Test func movingACardBackAndForthIsStuck() async {
        let model = GameModel(snapshot: GameSnapshot(
            stock: [card(.clubs, 3, faceUp: false), card(.diamonds, 6, faceUp: false)],
            tableau: [
                [card(.diamonds, 2, faceUp: false), card(.spades, 9)],
                [card(.clubs, 5, faceUp: false), card(.clubs, 9), card(.hearts, 8)],
                [], [], [], [], []
            ],
            drawCount: .one
        ))
        #expect(model.canMove(from: .tableau(column: 1, index: 2), to: .tableau(0)))
        #expect(model.isStuck)
        #expect(await model.checkIfStuck())
    }

    @Test func takingACardOffAFoundationAndBackIsStuck() {
        let model = GameModel(snapshot: GameSnapshot(
            stock: [card(.clubs, 6, faceUp: false)],
            foundations: [[card(.hearts, 1), card(.hearts, 2)], [], [], []],
            tableau: [[card(.diamonds, 7, faceUp: false), card(.spades, 3)], [], [], [], [], [], []],
            drawCount: .one
        ))
        #expect(model.canMove(from: .foundation(0), to: .tableau(0)))
        #expect(model.isStuck)
    }

    @Test func movesThatLeadToTurningOverACardAreProgress() {
        // Only after the 7♠ goes up can the 7♣ move onto the 8♥.
        let model = GameModel(snapshot: GameSnapshot(
            foundations: [(1...6).map { card(.spades, $0) }, [], [], []],
            tableau: [
                [card(.diamonds, 2, faceUp: false), card(.clubs, 7)],
                [card(.spades, 9), card(.hearts, 8), card(.spades, 7)],
                [], [], [], [], []
            ]
        ))
        #expect(!model.isStuck)
    }

    @Test func movesThatMakeRoomForADeckCardAreProgress() {
        // The 4♣ can go on the 5♥ once it comes down from its foundation.
        let model = GameModel(snapshot: GameSnapshot(
            stock: [card(.clubs, 4, faceUp: false)],
            foundations: [(1...5).map { card(.hearts, $0) }, [], [], []],
            tableau: [[card(.diamonds, 9, faceUp: false), card(.spades, 6)], [], [], [], [], [], []],
            drawCount: .one
        ))
        #expect(!model.isStuck)
    }

    @Test func aSuitCanComeDownInTurnToMakeRoom() {
        // The 6♥ comes down only so the 5♥ can follow it onto the 6♠ and take the 4♣.
        let model = GameModel(snapshot: GameSnapshot(
            stock: [card(.clubs, 4, faceUp: false)],
            foundations: [(1...6).map { card(.hearts, $0) }, [], [], []],
            tableau: [
                [card(.diamonds, 9, faceUp: false), card(.clubs, 7)],
                [card(.diamonds, 10, faceUp: false), card(.spades, 6)],
                [], [], [], [], []
            ],
            drawCount: .one
        ))
        #expect(!model.isStuck)
    }

    @Test func twoFoundationsCanComeDownToMakeRoom() {
        // The 7♥ comes down onto the 8♣, the 6♠ onto it, and then the 5♦ fits.
        let model = GameModel(snapshot: GameSnapshot(
            stock: [card(.diamonds, 5, faceUp: false)],
            foundations: [(1...7).map { card(.hearts, $0) }, (1...6).map { card(.spades, $0) }, [], []],
            tableau: [[card(.diamonds, 9, faceUp: false), card(.clubs, 8)], [], [], [], [], [], []],
            drawCount: .one
        ))
        #expect(!model.isStuck)
    }

    @Test func drawThreeOnlyReachesEveryThirdCard() {
        let stock = [
            card(.diamonds, 4, faceUp: false), card(.hearts, 8, faceUp: false), card(.clubs, 3, faceUp: false)
        ]
        let tableau = [[card(.clubs, 2, faceUp: false), card(.spades, 9)], [], [], [], [], [], []]

        let drawThree = GameModel(snapshot: GameSnapshot(stock: stock, tableau: tableau, drawCount: .three))
        #expect(drawThree.isStuck)

        let drawOne = GameModel(snapshot: GameSnapshot(stock: stock, tableau: tableau, drawCount: .one))
        #expect(!drawOne.isStuck)
    }

    @Test func faceUpRunsWithAnEmptyDeckCanBeCleared() {
        let suitPairs: [(Suit, Suit)] = [(.spades, .hearts), (.hearts, .spades), (.clubs, .diamonds), (.diamonds, .clubs)]
        let runs = suitPairs.map { odd, even in
            (1...13).reversed().map { rank in card(rank.isMultiple(of: 2) ? even : odd, rank) }
        }
        let model = GameModel(snapshot: GameSnapshot(tableau: runs + [[], [], []]))
        #expect(!model.isStuck)
    }

    @Test func allFoundationCardsProduceWin() {
        let foundations = Suit.allCases.map { suit in
            (1...13).map { card(suit, $0) }
        }
        let model = GameModel(snapshot: GameSnapshot(foundations: foundations))
        #expect(model.hasWon)
        #expect(!model.isStuck)
        #expect(!model.canUndo)
    }

    @Test func drawOneChargesForEveryPassAfterTheFirst() {
        let model = GameModel(snapshot: GameSnapshot(
            stock: [card(.spades, 1, faceUp: false)],
            drawCount: .one,
            score: 150
        ))

        model.drawFromStock()
        model.drawFromStock()
        #expect(model.game.recycles == 1)
        #expect(model.game.score == 50)

        model.drawFromStock()
        model.drawFromStock()
        #expect(model.game.recycles == 2)
        #expect(model.game.score == 0)
    }

    @Test func drawThreeAllowsThreePassesBeforeCharging() {
        let model = GameModel(snapshot: GameSnapshot(
            stock: [card(.spades, 1, faceUp: false)],
            drawCount: .three,
            score: 50
        ))

        var scores: [Int] = []
        for _ in 0..<4 {
            model.drawFromStock()
            model.drawFromStock()
            scores.append(model.game.score)
        }
        #expect(scores == [50, 50, 30, 10])
    }

    @Test func everyTenSecondsOfPlayCostsTwoPoints() {
        let model = GameModel(snapshot: GameSnapshot(
            waste: [card(.hearts, 1)],
            score: 50,
            elapsed: 35
        ))
        #expect(model.score() == 44)
        #expect(model.game.score == 50)

        model.move(from: .waste, to: .foundation(0))
        #expect(model.game.score == 54)
        #expect(model.game.timePenaltiesCharged == 3)
        #expect(model.score() == 54)
    }

    @Test func theTimePenaltyStopsAtZero() {
        let model = GameModel(snapshot: GameSnapshot(
            waste: [card(.hearts, 1)],
            score: 4,
            elapsed: 60
        ))
        #expect(model.score() == 0)

        model.move(from: .waste, to: .foundation(0))
        #expect(model.game.score == 10)
    }

    @Test func undoGivesBackAMovesPointsButNotTheTimePenalty() {
        let model = GameModel(snapshot: GameSnapshot(
            waste: [card(.hearts, 1)],
            score: 30,
            elapsed: 25
        ))

        model.move(from: .waste, to: .foundation(0))
        #expect(model.score() == 36)

        model.undo()
        #expect(model.game.score == 30)
        #expect(model.score() == 26)
    }

    @Test(arguments: [(20.0, 0), (31.0, 22_580), (100.0, 7_000)])
    func winningAddsATimeBonus(elapsed: Double, bonus: Int) {
        var foundations = Suit.allCases.map { suit in
            (1...13).map { card(suit, $0) }
        }
        let lastCard = foundations[0].removeLast()
        let model = GameModel(snapshot: GameSnapshot(
            waste: [lastCard],
            foundations: foundations,
            score: 600,
            elapsed: elapsed
        ))

        model.move(from: .waste, to: .foundation(0))

        #expect(model.hasWon)
        #expect(model.game.timeBonus == bonus)
        let timePenalty = Int(elapsed / 10) * 2
        #expect(model.score() == 600 - timePenalty + 10 + bonus)
    }

    @Test func savedGamesKeepTheirScoringState() throws {
        var game = GameSnapshot(stock: [card(.spades, 1, faceUp: false)], score: 42, elapsed: 125)
        game.recycles = 2
        game.timePenaltiesCharged = 5
        game.timeBonus = 7_000

        let loaded = try JSONDecoder().decode(GameSnapshot.self, from: JSONEncoder().encode(game))
        #expect(loaded == game)
    }

    @Test func gamesSavedBeforeStandardScoringStillLoad() throws {
        let saved = GameSnapshot(stock: [card(.spades, 1, faceUp: false)], score: 42, elapsed: 125)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        for key in ["recycles", "timePenaltiesCharged", "timeBonus"] {
            json[key] = nil
        }

        let loaded = try JSONDecoder().decode(GameSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(loaded.stock == saved.stock)
        #expect(loaded.score == 42)
        #expect(loaded.recycles == 0)
        // The time already played isn't charged after the update.
        #expect(loaded.timePenaltiesCharged == 12)
        #expect(GameModel(snapshot: loaded).score() == 42)
    }

    private func card(_ suit: Suit, _ rank: Int, faceUp: Bool = true) -> Card {
        Card(suit: suit, rank: rank, isFaceUp: faceUp)
    }
}

struct TimeFormattingTests {
    @Test(arguments: [
        (-5.0, "0:00"),
        (0.0, "0:00"),
        (59.9, "0:59"),
        (61.0, "1:01"),
        (754.0, "12:34"),
        (3_599.0, "59:59"),
        (3_600.0, "1:00:00"),
        (3_725.0, "1:02:05")
    ])
    func formatsElapsedTime(elapsed: Double, expected: String) {
        #expect(formatTime(elapsed) == expected)
    }
}

struct BoardLayoutTests {
    @Test(arguments: [180, 200, 320, 390])
    func boardFitsNarrowAvailableWidths(width: Double) {
        let layout = BoardLayout(game: GameSnapshot(), width: width)
        let rightEdge = layout.tableauFrames.map(\.maxX).max() ?? 0
        #expect(rightEdge <= width + 0.0001)
    }

    @Test func gutterKeepsCardsOutOfTheGap() {
        let layout = BoardLayout(game: GameSnapshot(), width: 600, gutter: 40)
        let stockSideEdge = layout.tableauFrames[2].maxX
        let foundationSideEdge = layout.tableauFrames[3].minX

        #expect(foundationSideEdge - stockSideEdge >= 40)
        #expect(layout.wasteFrame.maxX <= stockSideEdge)
        #expect(layout.foundationFrames[0].minX >= foundationSideEdge - 0.0001)
        #expect((layout.tableauFrames.last?.maxX ?? 0) <= 600 + 0.0001)
    }

    @Test func foldedPlacementSplitsTheBoardAtTheFold() {
        let fold: ClosedRange<CGFloat> = 455...495
        let placement = BoardPlacement(containerSize: CGSize(width: 867, height: 471), fold: fold)
        let layout = BoardLayout(game: GameSnapshot(), width: placement.width, gutter: placement.gutter)

        #expect(abs(placement.originX + layout.tableauFrames[2].maxX - fold.lowerBound) < 0.5)
        #expect(abs(placement.originX + layout.tableauFrames[3].minX - fold.upperBound) < 0.5)
        #expect(placement.originX + (layout.tableauFrames.last?.maxX ?? 0) <= 867)
        #expect(abs(placement.leadingWidth - layout.tableauFrames[2].maxX) < 0.5)
        #expect(abs(placement.trailingWidth - (layout.tableauFrames[6].maxX - layout.tableauFrames[3].minX)) < 0.5)
    }

    @Test(arguments: [(364.0, 478.0), (393.0, 700.0), (430.0, 800.0)])
    func narrowPortraitPlacementFillsTheWidth(width: Double, height: Double) {
        let placement = BoardPlacement(containerSize: CGSize(width: width, height: height))
        let padding = max(12, min(24, width * 0.025))

        #expect(placement.gutter == 0)
        #expect(abs(placement.width - (width - padding * 2)) < 0.0001)
        #expect(abs(placement.originX - padding) < 0.0001)
    }

    @Test func wideLandscapePlacementIsLimitedByHeight() {
        let placement = BoardPlacement(containerSize: CGSize(width: 867, height: 471))
        let layout = BoardLayout(game: GameSnapshot(), width: placement.width)

        let trailingMargin = 867 - placement.originX - placement.width
        #expect(placement.width < 867 - 48)
        #expect(abs(placement.originX - trailingMargin) < 0.0001)
        #expect(layout.cardWidth * 5.6 <= 471 + 0.5)
    }

    @Test func largeScreenPlacementStartsTheCardsAtItsOrigin() {
        // A window large enough to cap cards at their maximum size must not get
        // a board wider than its cards, or the stats line drifts off the stock.
        let placement = BoardPlacement(containerSize: CGSize(width: 1_194, height: 700))
        let layout = BoardLayout(game: GameSnapshot(), width: placement.width)

        #expect(layout.cardWidth > 111)
        #expect(abs(layout.stockFrame.minX) < 0.5)
        #expect(abs(layout.tableauFrames[6].maxX - placement.width) < 0.5)
    }

    @Test func longColumnsCloseUpBeforeTheBoardScrolls() {
        let run = (6...13).reversed().enumerated().map { offset, rank in
            Card(suit: offset.isMultiple(of: 2) ? .spades : .hearts, rank: rank, isFaceUp: true)
        }
        let game = GameSnapshot(tableau: [run, [], [], [], [], [], []])
        let roomy = BoardLayout(game: game, width: 390)
        let fitted = BoardLayout(game: game, width: 390, maxHeight: 290)
        let cramped = BoardLayout(game: game, width: 390, maxHeight: 200)

        #expect(fitted.tableauFrames[0].maxY <= 290 + 0.001)
        #expect(fitted.tableauFrames[0].maxY < roomy.tableauFrames[0].maxY)
        // Never tighter than the rank-only spacing; past that the board scrolls.
        let tightest = 7 * max(14, cramped.cardWidth * 0.28) + cramped.cardSize.height
        #expect(abs(cramped.tableauFrames[0].height - tightest) < 0.001)
    }

    @Test func dropPrefersLegalTargetOverLargerOverlap() {
        let layout = BoardLayout(game: GameSnapshot(), width: 390)
        let first = layout.foundationFrames[0]
        let second = layout.foundationFrames[1]
        let lead = first.offsetBy(dx: (second.minX - first.minX) * 0.4, dy: 0)

        #expect(layout.dropTarget(for: lead) == .foundation(0))
        #expect(layout.dropTarget(for: lead) { $0 != .foundation(0) } == .foundation(1))
        #expect(layout.dropTarget(for: lead) { _ in false } == nil)
    }
}
