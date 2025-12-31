import SwiftUI

struct GameCoordinatorView: View {
    let gameType: GameType
    let onBackToHome: () -> Void

    var body: some View {
        switch gameType {
        case .diagone:
            DiagoneCoordinatorView(onBackToHome: onBackToHome)
        case .testGame:
            TestGameCoordinatorView(onBackToHome: onBackToHome)
        }
    }
}

// MARK: - Diagone Coordinator
private struct DiagoneCoordinatorView: View {
    enum Route { case loading, playing }

    let onBackToHome: () -> Void
    @State private var route: Route = .loading
    @StateObject private var viewModel = GameViewModel(engine: GameEngine(puzzleDate: Date()))

    var body: some View {
        Group {
            switch route {
            case .loading:
                DiagoneLoadingView(
                    date: Date(),
                    onStart: {
                        viewModel.startGame()
                        route = .playing
                    },
                    onBack: onBackToHome
                )
            case .playing:
                DiagoneContentView(viewModel: viewModel, onBackToHome: onBackToHome)
            }
        }
    }
}

// MARK: - Test Game Coordinator
private struct TestGameCoordinatorView: View {
    enum Route { case loading, playing }

    let onBackToHome: () -> Void
    @State private var route: Route = .loading
    @StateObject private var viewModel = TestGameViewModel()

    var body: some View {
        Group {
            switch route {
            case .loading:
                TestGameLoadingView(
                    date: Date(),
                    onStart: {
                        viewModel.startGame()
                        route = .playing
                    },
                    onBack: onBackToHome
                )
            case .playing:
                TestGameView(viewModel: viewModel, onBackToHome: onBackToHome)
            }
        }
    }
}
