import SwiftUI

struct CardView: View {
    let card: Card
    let width: CGFloat

    private var height: CGFloat { width * 1.4 }
    private var cornerRadius: CGFloat { max(5, width * 0.1) }
    private var ink: Color { card.suit.isRed ? GameTheme.suitRed : GameTheme.ink }

    var body: some View {
        ZStack {
            if card.isFaceUp {
                face.accessibilityHidden(true)
            } else {
                back.accessibilityHidden(true)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 1.5, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.isFaceUp ? card.accessibilityName : "Face-down card")
    }

    private var face: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(GameTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(GameTheme.ink.opacity(0.2), lineWidth: 0.7)
                }

            cornerIndex
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(width * 0.065)

            cornerIndex
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(width * 0.065)

            Text(card.suit.symbol)
                .font(.system(size: width * 0.44, design: .serif))
                .foregroundStyle(ink)
                .offset(y: -height * 0.015)
        }
    }

    private var cornerIndex: some View {
        VStack(spacing: -width * 0.015) {
            Text(card.rankText)
                .font(.system(size: width * 0.19, weight: .bold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(card.suit.symbol)
                .font(.system(size: width * 0.145, design: .serif))
        }
        .foregroundStyle(ink)
        .frame(width: width * 0.22)
    }

    private var back: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let inset = max(2, width * 0.04)

        return ZStack {
            shape.fill(GameTheme.cardBack)

            Canvas { context, size in
                let step = max(7, width * 0.12)
                var diagonalPath = Path()
                var x = -size.height
                while x < size.width + size.height {
                    diagonalPath.move(to: CGPoint(x: x, y: 0))
                    diagonalPath.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    diagonalPath.move(to: CGPoint(x: x, y: size.height))
                    diagonalPath.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += step
                }
                context.stroke(
                    diagonalPath,
                    with: .color(GameTheme.accent.opacity(0.18)),
                    lineWidth: max(0.6, width * 0.012)
                )
            }
            .clipShape(shape)

            shape
                .stroke(GameTheme.cardBackEdge, lineWidth: max(1, width * 0.025))
                .padding(inset)
            shape
                .stroke(GameTheme.accent.opacity(0.55), lineWidth: 0.7)
                .padding(inset * 1.65)
        }
    }
}

struct EmptyPileView: View {
    let width: CGFloat
    var hint: String?
    var systemImage: String?
    var isHighlighted = false

    private var height: CGFloat { width * 1.4 }

    var body: some View {
        RoundedRectangle(cornerRadius: max(5, width * 0.1), style: .continuous)
            .stroke(
                isHighlighted ? GameTheme.accent : GameTheme.tableForeground.opacity(0.25),
                style: StrokeStyle(
                    lineWidth: isHighlighted ? 2 : 1.3,
                    dash: isHighlighted ? [] : [max(3, width * 0.07), max(3, width * 0.06)]
                )
            )
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: max(5, width * 0.1), style: .continuous)
                        .fill(GameTheme.accent.opacity(0.1))
                }
            }
            .overlay {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: width * 0.35, weight: .medium))
                } else if let hint {
                    Text(hint)
                        .font(.system(size: width * 0.33, weight: .medium, design: .serif))
                }
            }
            .foregroundStyle(
                isHighlighted ? GameTheme.accent : GameTheme.tableForeground.opacity(0.3)
            )
            .frame(width: width, height: height)
    }
}
