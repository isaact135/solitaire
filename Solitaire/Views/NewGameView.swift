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
            VStack(spacing: 22) {
                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(GameTheme.accent)
                    .symbolEffect(.bounce, options: .nonRepeating)

                VStack(spacing: 8) {
                    Text("You win!")
                        .font(.largeTitle.bold())
                    Text("Every suit is home.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
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
                .padding(.vertical, 8)

                Button(action: playAgain) {
                    Label("Play Again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.horizontal, 28)

                Spacer()
            }
            .padding()
            .navigationTitle("Congratulations")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(GameTheme.accent)
    }
}

private struct WinStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
