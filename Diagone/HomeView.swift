import SwiftUI

struct HomeView: View {
    let onGameSelected: (GameType) -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Daily Puzzles")
                        .font(.largeTitle.weight(.bold))
                        .padding(.top, 40)

                    ForEach(GameType.allCases) { game in
                        GameCard(gameType: game, onTap: {
                            onGameSelected(game)
                        })
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color(UIColor.systemGray6))
        }
    }
}

fileprivate struct GameCard: View {
    let gameType: GameType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                GameIconView(gameType: gameType)
                    .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 4) {
                    Text(gameType.displayName)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)

                    Text(gameType.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
            )
            .shadow(radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Game Icons
fileprivate struct GameIconView: View {
    let gameType: GameType

    var body: some View {
        switch gameType {
        case .diagone:
            DiagoneIconView(size: 54)
        case .rhymeAGrams:
            RhymeAGramsIconView(size: 54)
        case .tumblePuns:
            TumblePunsIconView(size: 54)
        }
    }
}

// RhymeAGrams: Pyramid of letter cells (1, 3, 5, 7 rows like the game)
fileprivate struct RhymeAGramsIconView: View {
    let size: CGFloat

    var body: some View {
        let cellSize = size * 0.12
        let spacing = size * 0.03

        VStack(spacing: spacing) {
            // Row 1: 1 cell
            HStack(spacing: spacing) {
                pyramidCell(size: cellSize)
            }
            // Row 2: 3 cells
            HStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { _ in
                    pyramidCell(size: cellSize)
                }
            }
            // Row 3: 5 cells
            HStack(spacing: spacing) {
                ForEach(0..<5, id: \.self) { _ in
                    pyramidCell(size: cellSize)
                }
            }
            // Row 4: 7 cells
            HStack(spacing: spacing) {
                ForEach(0..<7, id: \.self) { _ in
                    pyramidCell(size: cellSize)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func pyramidCell(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
            .fill(Color.mainDiagonal.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .stroke(Color.mainDiagonal.opacity(0.5), lineWidth: 0.5)
            )
    }
}

// Diagone: 6x6 grid with white diagonal cells with thick black outline
fileprivate struct DiagoneIconView: View {
    let size: CGFloat

    var body: some View {
        let cell = size / 6.0
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { c in
                        let isMain = (r == c)
                        Rectangle()
                            .fill(isMain ? Color.white : Color.boardCell)
                            .overlay(
                                Rectangle()
                                    .stroke(isMain ? Color.black : Color.gridLine, lineWidth: isMain ? 1.5 : 0.5)
                            )
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.gridLine, lineWidth: 1))
        .frame(width: size, height: size)
    }
}

// TumblePuns: 2x2 grid with each cell showing circles in a circle (matching the game layout)
fileprivate struct TumblePunsIconView: View {
    let size: CGFloat

    var body: some View {
        let cellSize = size * 0.45
        let spacing = size * 0.08

        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                TumblePunsWordCluster(size: cellSize, letterCount: 5)
                TumblePunsWordCluster(size: cellSize, letterCount: 5)
            }
            HStack(spacing: spacing) {
                TumblePunsWordCluster(size: cellSize, letterCount: 5)
                TumblePunsWordCluster(size: cellSize, letterCount: 5)
            }
        }
        .frame(width: size, height: size)
    }
}

// A single word cluster showing circles arranged in a circle
fileprivate struct TumblePunsWordCluster: View {
    let size: CGFloat
    let letterCount: Int

    var body: some View {
        let circleSize: CGFloat = size * 0.28
        let radius: CGFloat = size * 0.30

        ZStack {
            ForEach(0..<letterCount, id: \.self) { index in
                let angle = Angle(degrees: Double(index) * (360.0 / Double(letterCount)) - 90)
                Circle()
                    .fill(Color.boardCell)
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 0.5, x: 0, y: 0.5)
                    .offset(x: radius * cos(angle.radians), y: radius * sin(angle.radians))
            }
        }
        .frame(width: size, height: size)
    }
}
