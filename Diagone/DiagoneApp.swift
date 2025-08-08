import SwiftUI

/// The entry point for the Diagone application.
///
/// This small struct conforms to the `App` protocol and simply
/// constructs the main window containing the root `ContentView`.
/// The heavy lifting for game logic and UI lives elsewhere.
@main
struct DiagoneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}