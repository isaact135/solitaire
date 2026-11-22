import SwiftUI

struct GameBoardView: View {
    private struct DragSession {
        let leadID: String
        let source: CardSource
        let cardIDs: [String]
        var translation: CGSize
    }

    let model: GameModel
    let placement: BoardPlacement

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Gesture state also resets when a drag is cancelled (an alert appearing,
    // a scroll taking over), so a card can't be left stranded mid-drag.
    @GestureState(reset: { _, transaction in
        transaction.animation = UIAccessibility.isReduceMotionEnabled ? nil : .spring(duration: 0.25)
    })
    private var dragSession: DragSession?

    private let coordinateSpace = "solitaire-board"

    var body: some View {
        let layout = BoardLayout(
            game: model.game,
            width: placement.width,
            gutter: placement.gutter,
            maxHeight: placement.boardHeight
        )
        let highlightedTarget = activeTarget(in: layout)

        ZStack(alignment: .topLeading) {
            pilePlaceholders(layout: layout, highlightedTarget: highlightedTarget)

            ForEach(layout.entries) { entry in
                let isDragged = dragSession?.cardIDs.contains(entry.id) == true
                let translation = isDragged ? dragSession?.translation ?? .zero : .zero
                let dragIndex = dragSession?.cardIDs.firstIndex(of: entry.id)

                CardView(card: entry.card, width: layout.cardWidth)
                    .contentShape(Rectangle())
                    .shadow(
                        color: .black.opacity(isDragged ? 0.35 : 0),
                        radius: isDragged ? 12 : 0,
                        y: isDragged ? 8 : 0
                    )
                    .position(
                        x: entry.origin.x + layout.cardSize.width / 2 + translation.width,
                        y: entry.origin.y + layout.cardSize.height / 2 + translation.height
                    )
                    .zIndex(isDragged ? 1_000 + Double(dragIndex ?? 0) : Double(entry.zIndex))
                    .allowsHitTesting(entry.isInteractive)
                    .onTapGesture {
                        if entry.isStock {
                            model.drawFromStock()
                        } else if let source = entry.source {
                            model.smartMove(from: source)
                        }
                    }
                    .gesture(dragGesture(for: entry, in: layout))
                    .accessibilityHidden(!entry.isInteractive)
                    .accessibilityAddTraits(entry.isInteractive ? .isButton : [])
                    .accessibilityHint(accessibilityHint(for: entry))
            }
        }
        .frame(width: layout.width, height: layout.height, alignment: .topLeading)
        .coordinateSpace(.named(coordinateSpace))
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: model.game)
        .accessibilitySortPriority(1)
    }

    @ViewBuilder
    private func pilePlaceholders(layout: BoardLayout, highlightedTarget: DropTarget?) -> some View {
        if model.game.stock.isEmpty {
            Button(action: model.drawFromStock) {
                EmptyPileView(
                    width: layout.cardWidth,
                    systemImage: model.game.waste.isEmpty ? nil : "arrow.counterclockwise"
                )
            }
            .buttonStyle(.plain)
            .disabled(model.game.waste.isEmpty)
            .position(
                x: layout.stockFrame.midX,
                y: layout.stockFrame.midY
            )
            .accessibilityLabel(model.game.waste.isEmpty ? "Empty stock" : "Recycle waste")
            .accessibilityHint("Double-tap to turn the waste back into the stock")
        }

        if model.game.waste.isEmpty {
            EmptyPileView(width: layout.cardWidth)
                .position(x: layout.wasteFrame.midX, y: layout.wasteFrame.midY)
                .accessibilityHidden(true)
        }

        ForEach(layout.foundationFrames.indices, id: \.self) { index in
            let frame = layout.foundationFrames[index]
            if model.game.foundations[index].isEmpty {
                EmptyPileView(
                    width: layout.cardWidth,
                    hint: "A",
                    isHighlighted: highlightedTarget == .foundation(index)
                )
                .position(x: frame.midX, y: frame.midY)
                .accessibilityLabel("Foundation \(index + 1), empty")
            } else if highlightedTarget == .foundation(index) {
                dropHighlight(frame: frame)
            }
        }

        ForEach(layout.tableauFrames.indices, id: \.self) { column in
            let frame = layout.tableauFrames[column]
            let lastEntry = layout.entries.last { entry in
                guard let source = entry.source,
                      case let .tableau(entryColumn, _) = source else { return false }
                return entryColumn == column
            }
            let topFrame = CGRect(origin: lastEntry?.origin ?? frame.origin, size: layout.cardSize)
            if model.game.tableau[column].isEmpty {
                EmptyPileView(
                    width: layout.cardWidth,
                    hint: "K",
                    isHighlighted: highlightedTarget == .tableau(column)
                )
                .position(x: frame.midX, y: topFrame.midY)
                .accessibilityLabel("Tableau column \(column + 1), empty")
            } else if highlightedTarget == .tableau(column) {
                dropHighlight(frame: topFrame)
            }
        }
    }

    private func dropHighlight(frame: CGRect) -> some View {
        RoundedRectangle(cornerRadius: max(5, frame.width * 0.1), style: .continuous)
            .stroke(GameTheme.accent, lineWidth: 2.5)
            .background {
                RoundedRectangle(cornerRadius: max(5, frame.width * 0.1), style: .continuous)
                    .fill(GameTheme.accent.opacity(0.1))
            }
            .shadow(color: GameTheme.accent.opacity(0.35), radius: 8)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .zIndex(900)
            .allowsHitTesting(false)
    }

    private func dragGesture(for entry: BoardEntry, in layout: BoardLayout) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(coordinateSpace))
            .updating($dragSession) { value, session, _ in
                guard !model.hasWon, !entry.isStock, let source = entry.source else { return }
                if session == nil {
                    let cards = model.draggableCards(from: source)
                    guard !cards.isEmpty else { return }
                    session = DragSession(
                        leadID: entry.id,
                        source: source,
                        cardIDs: cards.map(\.id),
                        translation: value.translation
                    )
                }
                guard session?.leadID == entry.id else { return }
                session?.translation = value.translation
            }
            .onEnded { value in
                // The board may have changed mid-drag, so only drop the card
                // that is still being dragged from its source.
                guard !model.hasWon, !entry.isStock, let source = entry.source,
                      model.draggableCards(from: source).first?.id == entry.id else { return }
                let draggedFrame = CGRect(
                    x: entry.origin.x + value.translation.width,
                    y: entry.origin.y + value.translation.height,
                    width: layout.cardWidth,
                    height: layout.cardSize.height
                )
                guard let target = layout.dropTarget(for: draggedFrame, accepting: {
                    model.canMove(from: source, to: $0)
                }) else { return }
                withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) {
                    _ = model.move(from: source, to: target)
                }
            }
    }

    private func activeTarget(in layout: BoardLayout) -> DropTarget? {
        guard let session = dragSession,
              let entry = layout.entries.first(where: { $0.id == session.leadID }) else { return nil }
        let frame = CGRect(
            x: entry.origin.x + session.translation.width,
            y: entry.origin.y + session.translation.height,
            width: layout.cardWidth,
            height: layout.cardSize.height
        )
        return layout.dropTarget(for: frame) { model.canMove(from: session.source, to: $0) }
    }

    private func accessibilityHint(for entry: BoardEntry) -> String {
        if entry.isStock {
            return "Double-tap to draw \(model.game.drawCount.rawValue == 1 ? "one card" : "three cards")"
        }
        if !entry.card.isFaceUp {
            return "Double-tap to turn over"
        }
        return "Double-tap to auto-place, or drag to move"
    }
}
