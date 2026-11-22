import Foundation

enum Suit: String, Codable, CaseIterable, Sendable {
    case spades, hearts, diamonds, clubs

    var symbol: String {
        switch self {
        case .spades: "♠"
        case .hearts: "♥"
        case .diamonds: "♦"
        case .clubs: "♣"
        }
    }

    var isRed: Bool {
        self == .hearts || self == .diamonds
    }

    var name: String {
        rawValue.capitalized
    }
}

struct Card: Identifiable, Codable, Hashable, Sendable {
    var suit: Suit
    var rank: Int
    var isFaceUp = false

    var id: String { "\(suit.rawValue)-\(rank)" }

    var rankName: String {
        switch rank {
        case 1: "Ace"
        case 11: "Jack"
        case 12: "Queen"
        case 13: "King"
        default: String(rank)
        }
    }

    var rankText: String {
        switch rank {
        case 1: "A"
        case 11: "J"
        case 12: "Q"
        case 13: "K"
        default: String(rank)
        }
    }

    var accessibilityName: String {
        "\(rankName) of \(suit.name)"
    }

    static var deck: [Card] {
        Suit.allCases.flatMap { suit in
            (1...13).map { Card(suit: suit, rank: $0) }
        }
    }
}

enum DrawCount: Int, Codable, CaseIterable, Identifiable, Sendable {
    case one = 1
    case three = 3

    var id: Int { rawValue }
    var title: String { "Draw \(rawValue)" }
}

struct GameSnapshot: Codable, Equatable, Sendable {
    var stock: [Card] = []
    var waste: [Card] = []
    var foundations: [[Card]] = [[], [], [], []]
    var tableau: [[Card]] = [[], [], [], [], [], [], []]
    var drawCount: DrawCount = .three
    var score = 0
    var moves = 0
    var elapsed: TimeInterval = 0
    /// How many times the waste has been turned back over.
    var recycles = 0
    /// How many 10-second periods of play have been taken off `score`.
    var timePenaltiesCharged = 0
    /// The bonus added to `score` for the time a won game took.
    var timeBonus = 0
}

extension GameSnapshot {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stock = try container.decode([Card].self, forKey: .stock)
        waste = try container.decode([Card].self, forKey: .waste)
        foundations = try container.decode([[Card]].self, forKey: .foundations)
        tableau = try container.decode([[Card]].self, forKey: .tableau)
        drawCount = try container.decode(DrawCount.self, forKey: .drawCount)
        score = try container.decode(Int.self, forKey: .score)
        moves = try container.decode(Int.self, forKey: .moves)
        elapsed = try container.decode(TimeInterval.self, forKey: .elapsed)
        // Games saved before standard scoring don't have these. Their time so
        // far counts as already charged, so the penalty starts from now.
        recycles = try container.decodeIfPresent(Int.self, forKey: .recycles) ?? 0
        timePenaltiesCharged = try container.decodeIfPresent(Int.self, forKey: .timePenaltiesCharged)
            ?? Int(elapsed / Scoring.timePenaltyInterval)
        timeBonus = try container.decodeIfPresent(Int.self, forKey: .timeBonus) ?? 0
    }
}

enum CardSource: Hashable, Sendable {
    case waste
    case foundation(Int)
    case tableau(column: Int, index: Int)
}

enum DropTarget: Hashable, Sendable {
    case foundation(Int)
    case tableau(Int)
}
