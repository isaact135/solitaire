import SwiftUI

struct GameView: View {
    let model: GameModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var showNewGame = false
    @State private var isStuck = false
    @State private var showStuck = false
    @State private var showWin = false
    @State private var statsBarHeight: CGFloat = 26

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                // The stats line and the board share one placement so the line
                // sits on the board's leading edge, and both avoid the fold.
                let placement = BoardPlacement(
                    containerSize: CGSize(
                        width: proxy.size.width,
                        height: proxy.size.height - statsBarHeight
                    ),
                    fold: proxy.verticalFold
                )
                BoardContainer(model: model, placement: placement)
                    .safeAreaBar(edge: .top, spacing: 0) {
                        GameStatsBar(model: model, placement: placement)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                statsBarHeight = height
                            }
                    }
            }
            .background(GameBackground())
            .navigationTitle("Solitaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: model.undo) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!model.canUndo)
                    .accessibilityHint("Restores the previous position")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewGame = true } label: {
                        Label("New Game", systemImage: "plus")
                    }
                    .accessibilityHint("Choose a draw mode and deal a new game")
                }
            }
        }
        .tint(GameTheme.accent)
        .sensoryFeedback(.impact(weight: .light), trigger: model.game.moves)
        .sensoryFeedback(.success, trigger: model.hasWon) { _, hasWon in hasWon }
        .sheet(isPresented: $showNewGame) {
            NewGameView(initialDrawCount: model.game.drawCount) { drawCount in
                startNewGame(drawCount: drawCount)
            }
        }
        .sheet(isPresented: $showWin) {
            WinView(model: model) {
                startNewGame(drawCount: model.game.drawCount)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("No useful moves left", isPresented: $showStuck) {
            Button("Undo Move", action: model.undo)
                .disabled(!model.canUndo)
            Button("New Deal") { startNewGame(drawCount: model.game.drawCount) }
            Button("Keep Looking", role: .cancel) {}
        } message: {
            Text("No move will turn over another card or play one from the deck. Undo a move or start a new deal.")
        }
        .task(id: model.game) {
            let stuck = await model.checkIfStuck()
            if !Task.isCancelled { isStuck = stuck }
        }
        // Alerts once each time the game becomes stuck, not after every move.
        .task(id: isStuck) {
            guard isStuck else { return }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            showStuck = true
        }
        .onChange(of: model.hasWon) { _, hasWon in
            if hasWon { showWin = true }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.resume()
            case .inactive, .background: model.pause()
            default: break
            }
        }
        .onAppear {
            showWin = model.hasWon
        }
    }

    private func startNewGame(drawCount: DrawCount) {
        showNewGame = false
        showWin = false
        showStuck = false
        model.newGame(drawCount: drawCount)
    }
}

private struct GameBackground: View {
    var body: some View {
        ZStack {
            GameTheme.table
            RadialGradient(
                colors: [GameTheme.tableLight.opacity(0.75), GameTheme.table.opacity(0)],
                center: .top,
                startRadius: 10,
                endRadius: 650
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.18)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct BoardContainer: View {
    let model: GameModel
    let placement: BoardPlacement

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                GameBoardView(model: model, placement: placement)
                Text("Tap a card to auto-place it, or drag to move stacks.")
                    .font(.footnote)
                    .foregroundStyle(GameTheme.tableForeground.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .frame(width: placement.leadingWidth)
                    .accessibilityHidden(true)
            }
            .padding(.leading, placement.originX)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

extension GeometryProxy {
    /// The span of an active vertical fold, such as a half-open iPhone Duo's
    /// hinge, in this proxy's coordinate space.
    var verticalFold: ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *),
              let fold = reservedRegions(kind: .division).first(where: {
                  $0.isActive && $0.frame.height > $0.frame.width
              }) else { return nil }
        return fold.frame.minX...fold.frame.maxX
    }
}

