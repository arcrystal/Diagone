import SwiftUI

struct AppCoordinatorView: View {
    enum Route {
        case splash
        case home
        case game(GameType)
    }

    @State private var route: Route = .splash

    var body: some View {
        Group {
            switch route {
            case .splash:
                SplashScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.4)) {
                                route = .home
                            }
                        }
                    }
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

// MARK: - Splash Screen
struct SplashScreen: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            // Blue background
            Color(red: 0.12, green: 0.35, blue: 0.65)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated logo - 6x6 grid with white diagonal
                SplashGridIcon(size: 100)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Text("Daily Puzzles")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                textOpacity = 1.0
            }
        }
    }
}

fileprivate struct SplashGridIcon: View {
    let size: CGFloat

    var body: some View {
        let cell = size / 6.0
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { c in
                        let isMain = (r == c)
                        Rectangle()
                            .fill(isMain ? Color.white : Color.white.opacity(0.2))
                            .overlay(
                                Rectangle()
                                    .stroke(isMain ? Color.black : Color.white.opacity(0.4), lineWidth: isMain ? 2 : 0.75)
                            )
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.5), lineWidth: 1))
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}
