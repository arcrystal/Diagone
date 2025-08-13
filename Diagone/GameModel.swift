import Foundation
import UIKit

// MARK: - Pieces & Diagonals

public struct GamePiece: Identifiable, Codable, Equatable {
    public let id: String
    public let letters: String
    public var placedOn: String?

    public var length: Int { letters.count }
}

public struct GameTarget: Identifiable, Codable, Equatable {
    public let id: String
    /// Ordered cells covered by this diagonal (top-left → bottom-right).
    let cells: [Cell]
    public let length: Int
    public var pieceId: String?

    init(id: String, cells: [Cell], pieceId: String? = nil) {
        self.id = id
        self.cells = cells
        self.length = cells.count
        self.pieceId = pieceId
    }
}

public struct MainDiagonal: Codable, Equatable {
    let cells: [Cell]
    public var value: [String]

    init(cells: [Cell]) {
        self.cells = cells
        self.value = Array(repeating: "", count: cells.count)
    }
}

// MARK: - State

public struct GameState: Codable, Equatable {
    public var board: [[String]]
    public var targets: [GameTarget]
    public var mainDiagonal: MainDiagonal
    public var pieces: [GamePiece]
    public var solved: Bool
    

    public init(board: [[String]],
                targets: [GameTarget],
                mainDiagonal: MainDiagonal,
                pieces: [GamePiece],
                solved: Bool = false) {
        self.board = board
        self.targets = targets
        self.mainDiagonal = mainDiagonal
        self.pieces = pieces
        self.solved = solved
    }
}

// MARK: - Configuration

public struct PuzzleConfiguration: Codable {
    /// All diagonals, with the main diagonal first (index 0).
    let diagonals: [[Cell]]
    public let pieceLetters: [String]

    public static func defaultConfiguration() -> PuzzleConfiguration {
        // Main diagonal
        var diagonals: [[Cell]] = []
        var main: [Cell] = []
        for i in 0..<6 { main.append(Cell(row: i, col: i)) }
        diagonals.append(main)

        // Non-main diagonals (upper then lower, both parallel to main)
        var diagCells: [[Cell]] = []

        // Upper diagonals (start at row 0, col offset 1..5)
        for offset in 1..<6 {
            var cells: [Cell] = []
            var r = 0
            var c = offset
            while r < 6 && c < 6 {
                cells.append(Cell(row: r, col: c))
                r += 1; c += 1
            }
            diagCells.append(cells)
        }
        // Lower diagonals (start at col 0, row offset 1..5)
        for offset in 1..<6 {
            var cells: [Cell] = []
            var r = offset
            var c = 0
            while r < 6 && c < 6 {
                cells.append(Cell(row: r, col: c))
                r += 1; c += 1
            }
            diagCells.append(cells)
        }

        // Sort by length ascending, then by starting cell (row, then col)
        diagCells.sort { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count < rhs.count }
            let l = lhs.first ?? Cell(row: 0, col: 0)
            let r = rhs.first ?? Cell(row: 0, col: 0)
            return (l.row, l.col) < (r.row, r.col)
        }

        diagonals.append(contentsOf: diagCells)

        // Provided piece set
        let pieceStrings = [
            "M", "E",
            "RA", "SE",
            "ALD", "WEN",
            "FAGI", "RBEY",
            "RAYAA", "HBLAN"
        ]

        return PuzzleConfiguration(diagonals: diagonals, pieceLetters: pieceStrings)
    }
}

// MARK: - Engine

public final class GameEngine: ObservableObject {
    @Published public var state: GameState
    

    private var history: [GameState] = []
    private var future: [GameState] = []

    public let configuration: PuzzleConfiguration

    public init(configuration: PuzzleConfiguration = .defaultConfiguration()) {
        self.configuration = configuration
        self.state = GameEngine.createInitialState(configuration: configuration)
    }

    private static func createInitialState(configuration: PuzzleConfiguration) -> GameState {
        // Pieces p1..pN
        var pieces: [GamePiece] = []
        for (i, letters) in configuration.pieceLetters.enumerated() {
            pieces.append(GamePiece(id: "p\(i+1)", letters: letters, placedOn: nil))
        }

        // Targets from non-main diagonals
        var targets: [GameTarget] = []
        var currentLen = 0
        var suffix: Character = "a"
        for diag in configuration.diagonals.dropFirst() {
            if diag.count != currentLen {
                currentLen = diag.count
                suffix = "a"
            }
            let id = "d_len\(currentLen)_\(suffix)"
            suffix = (suffix == "a") ? "b" : "a"
            targets.append(GameTarget(id: id, cells: diag))
        }

        // Main diagonal
        let main = MainDiagonal(cells: configuration.diagonals.first ?? [])

        // Empty 6×6 board
        let emptyRow = Array(repeating: "", count: 6)
        let board = Array(repeating: emptyRow, count: 6)

        return GameState(board: board, targets: targets, mainDiagonal: main, pieces: pieces)
    }

    // MARK: Actions

    public func reset() {
        history.removeAll()
        future.removeAll()
        state = GameEngine.createInitialState(configuration: configuration)
    }

    public func validTargets(for pieceId: String) -> [String] {
        guard let piece = state.pieces.first(where: { $0.id == pieceId }) else { return [] }
        return state.targets
            .filter { $0.length == piece.length && $0.pieceId == nil }
            .map { $0.id }
    }

    @discardableResult
    public func placePiece(pieceId: String, on targetId: String) -> Bool {
        guard let pIdx = state.pieces.firstIndex(where: { $0.id == pieceId }),
              let tIdx = state.targets.firstIndex(where: { $0.id == targetId }) else { return false }

        var piece = state.pieces[pIdx]
        let target = state.targets[tIdx]

        // Length & vacancy
        guard target.length == piece.length else { return false }
        guard state.targets[tIdx].pieceId == nil else { return false }

        // Conflict check
        for (letter, cell) in zip(piece.letters, target.cells) {
            let existing = state.board[cell.row][cell.col]
            if !existing.isEmpty && existing != String(letter) {
                return false
            }
        }

        // Commit with undo snapshot
        history.append(state); future.removeAll()

        piece.placedOn = target.id
        state.pieces[pIdx] = piece
        state.targets[tIdx].pieceId = piece.id

        recomputeBoard()
        return true
    }

    @discardableResult
    public func removePiece(from targetId: String) -> String? {
        guard let tIdx = state.targets.firstIndex(where: { $0.id == targetId }),
              let pieceId = state.targets[tIdx].pieceId,
              let pIdx = state.pieces.firstIndex(where: { $0.id == pieceId }) else { return nil }

        history.append(state); future.removeAll()

        state.targets[tIdx].pieceId = nil
        state.pieces[pIdx].placedOn = nil

        recomputeBoard()
        return pieceId
    }

    public func setMainDiagonal(_ letters: [String]) {
        guard letters.count == state.mainDiagonal.cells.count else { return }
        history.append(state); future.removeAll()
        state.mainDiagonal.value = letters
        recomputeBoard()
    }

    // MARK: Recompute & Validate

    private func recomputeBoard() {
        var newBoard = Array(repeating: Array(repeating: "", count: 6), count: 6)

        // Write piece letters
        for target in state.targets {
            guard let pid = target.pieceId,
                  let piece = state.pieces.first(where: { $0.id == pid }) else { continue }
            for (ch, cell) in zip(piece.letters, target.cells) {
                newBoard[cell.row][cell.col] = String(ch)
            }
        }

        // Write main diagonal
        for (letter, cell) in zip(state.mainDiagonal.value, state.mainDiagonal.cells) {
            newBoard[cell.row][cell.col] = letter
        }

        state.board = newBoard
        state.solved = isSolved()
    }

    private func isSolved() -> Bool {
        let allPlaced = state.targets.allSatisfy { $0.pieceId != nil }
        let mainFilled = state.mainDiagonal.value.allSatisfy { !$0.isEmpty }
        guard allPlaced && mainFilled else { return false }

        for r in 0..<6 {
            let word = state.board[r].joined()
            guard word.count == 6, GameEngine.isValidWord(word) else { return false }
        }
        return true
    }

    private static func isValidWord(_ word: String) -> Bool {
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: (word as NSString).length)
        let miss = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en_US")
        return miss.location == NSNotFound
    }

    // MARK: Undo/Redo

    @discardableResult
    public func undo() -> Bool {
        guard let prev = history.popLast() else { return false }
        future.append(state)
        state = prev
        return true
    }

    @discardableResult
    public func redo() -> Bool {
        guard let next = future.popLast() else { return false }
        history.append(state)
        state = next
        return true
    }
}
