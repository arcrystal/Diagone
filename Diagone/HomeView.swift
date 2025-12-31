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
                Image(systemName: gameType.iconSystemName)
                    .font(.system(size: 48))
                    .foregroundColor(.primary)
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
