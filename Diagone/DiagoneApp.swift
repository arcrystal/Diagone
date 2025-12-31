import SwiftUI

/// Application entry point. Launches the game UI within a single window. The
/// `@main` attribute ensures this struct is used as the main entry when
/// building an iOS app. On launch the app displays the home screen with
/// multiple game options.
@main
struct DiagoneApp: App {
    var body: some Scene {
        WindowGroup {
            AppCoordinatorView()
        }
    }
}
