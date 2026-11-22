import SwiftUI

/// A single quiet line of stats on the board's top-left corner. On a split
/// board it stays on the stock side, clear of the fold.
struct GameStatsBar: View {
    let model: GameModel
    let placement: BoardPlacement

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) {
                    clock(at: context.date)
                    moves
                    score(at: context.date)
                }
                VStack(alignment: .leading, spacing: 2) {
                    clock(at: context.date)
                    HStack(spacing: 18) {
                        moves
                        score(at: context.date)
                    }
                }
            }
            .font(.subheadline)
            .frame(width: placement.leadingWidth, alignment: .leading)
            .padding(.leading, placement.originX)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var moves: some View {
        Stat(value: model.game.moves, unit: model.game.moves == 1 ? "move" : "moves", label: "Moves")
    }

    /// The score loses 2 points every 10 seconds, so it's read at each tick.
    private func score(at date: Date) -> some View {
        let score = model.score(at: date)
        return Stat(value: score, unit: score == 1 ? "point" : "points", label: "Score")
    }

    private func clock(at date: Date) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "timer")
                .foregroundStyle(GameTheme.accent)
                .accessibilityHidden(true)
            ClockDigits(
                elapsed: model.elapsed(at: date),
                hasStarted: model.hasStarted,
                font: .subheadline.weight(.semibold)
            )
        }
    }
}

private struct ClockDigits: View {
    let elapsed: TimeInterval
    let hasStarted: Bool
    let font: Font

    var body: some View {
        Text(formatTime(elapsed))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(GameTheme.tableForeground.opacity(hasStarted ? 1 : 0.6))
            .lineLimit(1)
            .accessibilityLabel("Time")
            .accessibilityValue(spokenTime(elapsed))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct Stat: View {
    let value: Int
    let unit: String
    let label: LocalizedStringKey

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            Text(value, format: .number)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(GameTheme.tableForeground)
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(value)))
                .animation(reduceMotion ? nil : .snappy, value: value)
            Text(unit)
                .foregroundStyle(GameTheme.tableForeground.opacity(0.65))
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value, format: .number))
    }
}

func formatTime(_ elapsed: TimeInterval) -> String {
    let seconds = max(0, Int(elapsed))
    if seconds >= 3_600 {
        return String(format: "%d:%02d:%02d", seconds / 3_600, seconds / 60 % 60, seconds % 60)
    }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}

private func spokenTime(_ elapsed: TimeInterval) -> String {
    Duration.seconds(max(0, Int(elapsed)))
        .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
}
