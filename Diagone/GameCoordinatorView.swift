import SwiftUI

struct GameCoordinatorView: View {
    let gameType: GameType
    let onBackToHome: () -> Void

    var body: some View {
        switch gameType {
        case .diagone:
            DiagoneCoordinatorView(onBackToHome: onBackToHome)
        case .rhymeAGrams:
            RhymeAGramsCoordinatorView(onBackToHome: onBackToHome)
        case .tumblePuns:
            TumblePunsCoordinatorView(onBackToHome: onBackToHome)
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
                        route = .playing
                    },
                    onBack: onBackToHome
                )
            case .playing:
                DiagoneContentView(viewModel: viewModel, onBackToHome: onBackToHome)
            }
        }
        .onAppear {
            // Skip loading screen if game is already in progress or completed
            if viewModel.started {
                route = .playing
            }
        }
    }
}

// MARK: - RhymeAGrams Coordinator
private struct RhymeAGramsCoordinatorView: View {
    enum Route { case loading, playing }

    let onBackToHome: () -> Void
    @State private var route: Route = .loading
    @StateObject private var viewModel = RhymeAGramsViewModel()

    var body: some View {
        Group {
            switch route {
            case .loading:
                RhymeAGramsLoadingView(
                    date: Date(),
                    onStart: {
                        route = .playing
                    },
                    onBack: onBackToHome
                )
            case .playing:
                RhymeAGramsView(viewModel: viewModel, onBackToHome: onBackToHome)
            }
        }
        .onAppear {
            // Skip loading screen if game is already in progress or completed
            if viewModel.started {
                route = .playing
            }
        }
    }
}

// MARK: - TumblePuns Coordinator
private struct TumblePunsCoordinatorView: View {
    enum Route { case loading, playing }

    let onBackToHome: () -> Void
    @State private var route: Route = .loading
    @StateObject private var viewModel = TumblePunsViewModel()

    var body: some View {
        Group {
            switch route {
            case .loading:
                TumblePunsLoadingView(
                    date: Date(),
                    onStart: {
                        route = .playing
                    },
                    onBack: onBackToHome
                )
            case .playing:
                TumblePunsView(viewModel: viewModel, onBackToHome: onBackToHome)
            }
        }
        .onAppear {
            // Skip loading screen if game is already in progress or completed
            if viewModel.started {
                route = .playing
            }
        }
    }
}
