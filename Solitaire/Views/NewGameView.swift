import SwiftUI

struct NewGameView: View {
    let initialDrawCount: DrawCount
    let deal: (DrawCount) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drawCount: DrawCount

    init(initialDrawCount: DrawCount, deal: @escaping (DrawCount) -> Void) {
        self.initialDrawCount = initialDrawCount
        self.deal = deal
        _drawCount = State(initialValue: initialDrawCount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Cards per draw", selection: $drawCount) {
                        ForEach(DrawCount.allCases) { count in
                            Text(count.title).tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Draw 1 is more relaxed. Draw 3 follows traditional Klondike rules.")
                }

                Section {
                    Button {
                        deal(drawCount)
                        dismiss()
                    } label: {
                        Label("Deal Cards", systemImage: "rectangle.stack.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .foregroundStyle(GameTheme.ink)
                    .controlSize(.large)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .tint(GameTheme.accent)
    }
}

struct WinView: View {
    let model: GameModel
    let playAgain: () -> Void

    var body: some View {
        NavigationStack {
            // The sheet is half the screen tall, which is short on a landscape
            // screen. A tighter layout takes over when the full one doesn't
            // fit, and it scrolls if even that doesn't, as at the largest text
            // sizes.
            ViewThatFits(in: .vertical) {
                content(compact: false)
                content(compact: true)
                ScrollView {
                    content(compact: true)
                }
            }
            .navigationTitle("Congratulations")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(GameTheme.accent)
    }

    private func content(compact: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: compact ? 40 : 64))
                .foregroundStyle(GameTheme.accent)
                .symbolEffect(.bounce, options: .nonRepeating)

            gap(compact ? 12 : 22)

            VStack(spacing: compact ? 4 : 8) {
                Text("You win!")
                    .font(compact ? .title.bold() : .largeTitle.bold())
                Text("Every suit is home.")
                    .font(compact ? .body : .title3)
                    .foregroundStyle(.secondary)
            }

            gap(compact ? 12 : 30)

            VStack(spacing: compact ? 6 : 10) {
                HStack(spacing: 24) {
                    WinStat(title: "Time", value: formatTime(model.elapsed()))
                    WinStat(title: "Moves", value: model.game.moves.formatted())
                    WinStat(title: "Score", value: model.score().formatted())
                }
                if model.game.timeBonus > 0 {
                    Text("Includes a time bonus of \(model.game.timeBonus.formatted()) points.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            gap(compact ? 12 : 30)

            Button(action: playAgain) {
                Label("Play Again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 28)

            Spacer(minLength: 0)
        }
        .padding(compact ? 12 : 16)
    }

    /// Space between sections: the full gap when there's room, shrinking to
    /// half of it before the layout has to switch.
    private func gap(_ full: CGFloat) -> some View {
        Spacer(minLength: full / 2)
            .frame(maxHeight: full)
    }
}

private struct WinStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            // Large text sizes shrink a number to fit the width rather than
            // split it across lines. Its height stays fixed, so a short sheet
            // can't squeeze it.
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
