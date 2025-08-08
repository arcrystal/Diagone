import Foundation

/// Represents a single cell coordinate within the 6×6 grid.
/// Rows and columns are zero‑indexed with values in the range 0…5.
/// Conforming to `Hashable` allows easy use in dictionary keys and sets.
struct CellCoordinate: Hashable, Codable {
    let row: Int
    let col: Int
}

/// Describes one of the 10 non‑main diagonals that a piece can occupy.
/// Each diagonal has a unique identifier, a list of cells it occupies
/// (in order from topmost/leftmost to bottommost/rightmost), and
/// optionally a piece currently occupying it. The `length` property is
/// derived from the number of cells.
struct DiagonalTarget: Identifiable, Codable {
    let id: String
    let cells: [CellCoordinate]
    var pieceId: UUID? = nil

    /// The number of cells on this diagonal. Used for matching to a piece
    /// length when placing.
    var length: Int { cells.count }
}

/// A draggable piece containing a sequence of letters. Each piece has a
/// unique identifier, a string of uppercase characters, and an optional
/// placement (the id of a diagonal). The `length` is derived from
/// the number of letters in its sequence.
struct GamePiece: Identifiable, Codable {
    let id: UUID
    let letters: String
    var placedTargetId: String? = nil

    /// The number of letters this piece contains.
    var length: Int { letters.count }
}