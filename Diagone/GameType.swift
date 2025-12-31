import SwiftUI

enum GameType: String, Identifiable, CaseIterable {
    case diagone
    case testGame

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diagone: return "Diagone"
        case .testGame: return "Test Game"
        }
    }

    var iconSystemName: String {
        switch self {
        case .diagone: return "square.grid.3x3.fill"
        case .testGame: return "questionmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .diagone: return "Drag and drop diagonals to spell six horizontal words"
        case .testGame: return "A simple test game"
        }
    }
}
