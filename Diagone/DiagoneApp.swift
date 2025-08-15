import SwiftUI

/// Application entry point. Launches the game UI within a single window. The
/// `@main` attribute ensures this struct is used as the main entry when
/// building an iOS app. On launch the app displays `ContentView` which in
/// turn instantiates its own view model.
@main
struct DiagoneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: GameViewModel(engine: GameEngine(puzzleDate: Date())))
        }
    }
}
