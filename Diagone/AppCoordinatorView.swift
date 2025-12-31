import SwiftUI

struct AppCoordinatorView: View {
    enum Route {
        case home
        case game(GameType)
    }

    @State private var route: Route = .home

    var body: some View {
        Group {
            switch route {
            case .home:
                HomeView(onGameSelected: { gameType in
                    route = .game(gameType)
                })
            case .game(let gameType):
                GameCoordinatorView(gameType: gameType, onBackToHome: {
                    route = .home
                })
            }
        }
    }
}
