import SwiftUI

enum GameType: String, Identifiable, CaseIterable {
    case diagone
    case rhymeAGrams

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diagone: return "Diagone"
        case .rhymeAGrams: return "RhymeAGrams"
        }
    }

    var iconSystemName: String {
        switch self {
        case .diagone: return "square.grid.3x3.fill"
        case .rhymeAGrams: return "triangle.fill"
        }
    }

    var description: String {
        switch self {
        case .diagone: return "Drag and drop diagonals to spell six horizontal words"
        case .rhymeAGrams: return "Find four 4-letter words from a pyramid of letters"
        }
    }
}
