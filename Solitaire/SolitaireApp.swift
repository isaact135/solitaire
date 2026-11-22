import SwiftUI

@main
struct SolitaireApp: App {
    @State private var model = GameModel()

    var body: some Scene {
        WindowGroup {
            GameView(model: model)
                .tint(GameTheme.accent)
        }
    }
}
