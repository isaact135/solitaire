import Foundation

/// Standard scoring, as in classic Windows Solitaire.
enum Scoring {
    /// A card from the waste to a column.
    static let wasteToTableau = 5
    /// A card to a foundation, from the waste or a column.
    static let toFoundation = 10
    /// Turning over a face-down card in a column.
    static let turnOver = 5
    /// A card back from a foundation to a column.
    static let foundationToTableau = -15

    /// Every full 10 seconds of play costs 2 points.
    static let timePenalty = 2
    static let timePenaltyInterval: TimeInterval = 10

    /// The cost of turning the waste back over for the given time. Draw 1
    /// allows one pass through the deck, then charges 100 points for each
    /// pass after it. Draw 3 allows three passes, then charges 20.
    static func recyclePenalty(forRecycle recycle: Int, drawCount: DrawCount) -> Int {
        switch drawCount {
        case .one: recycle >= 1 ? 100 : 0
        case .three: recycle >= 3 ? 20 : 0
        }
    }

    /// A win that takes more than 30 seconds earns 700,000 points divided by
    /// the seconds it took.
    static func timeBonus(elapsed: TimeInterval) -> Int {
        let seconds = Int(elapsed)
        return seconds > 30 ? 700_000 / seconds : 0
    }
}
