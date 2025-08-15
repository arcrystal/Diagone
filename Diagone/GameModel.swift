import Foundation
import UIKit

// MARK: - Puzzle Utilities
fileprivate enum PuzzleBuilder {
    /// Expects exactly six words of length 6 each, already uppercased.
    static func pieceLetters(from words: [String]) -> [String] {
        precondition(words.count == 6, "Expected 6 words")
        // Guard lengths; if malformed, best-effort pad/truncate
        let w = words.map { s -> String in
            let up = s.uppercased()
            if up.count >= 6 { return String(up.prefix(6)) }
            return up.padding(toLength: 6, withPad: " ", startingAt: 0)
        }
        func char(_ wordIndex: Int, _ letterIndex: Int) -> String {
            let s = w[wordIndex]
            let idx = s.index(s.startIndex, offsetBy: letterIndex)
            return String(s[idx])
        }
        var pieces: [String] = []
        // A diagonals (upper), lengths 1..5
        // 1A: w1[5]
        pieces.append(char(0,5))
        // 1B: w6[0]
        pieces.append(char(5,0))
        // 2A: w1[4], w2[5]
        pieces.append(char(0,4) + char(1,5))
        // 2B: w5[0], w6[1]
        pieces.append(char(4,0) + char(5,1))
        // 3A: w1[3], w2[4], w3[5]
        pieces.append(char(0,3) + char(1,4) + char(2,5))
        // 3B: w4[0], w5[1], w6[2]
        pieces.append(char(3,0) + char(4,1) + char(5,2))
        // 4A: w1[2], w2[3], w3[4], w4[5]
        pieces.append(char(0,2) + char(1,3) + char(2,4) + char(3,5))
        // 4B: w3[0], w4[1], w5[2], w6[3]
        pieces.append(char(2,0) + char(3,1) + char(4,2) + char(5,3))
        // 5A: w1[1], w2[2], w3[3], w4[4], w5[5]
        pieces.append(char(0,1) + char(1,2) + char(2,3) + char(3,4) + char(4,5))
        // 5B: w2[0], w3[1], w4[2], w5[3], w6[4]
        pieces.append(char(1,0) + char(2,1) + char(3,2) + char(4,3) + char(5,4))
        return pieces
    }
}

// MARK: - Puzzle Library Loader
fileprivate enum PuzzleLibrary {
    struct Store: Decodable { let map: [String:[String]] }
    /// Loads a JSON dictionary mapping "MM/DD/YYYY" -> [six words].
    /// Supports bundled subdirectory + filename (default: Puzzles/puzzles.json).
    static func load(resource: String = "puzzles", subdirectory: String = "Puzzles") -> [String:[String]]? {
        let bundle = Bundle.main

        func decodeMap(from data: Data) -> [String:[String]]? {
            if let mapOnly = try? JSONDecoder().decode([String:[String]].self, from: data) { return mapOnly }
            if let wrapped = try? JSONDecoder().decode(Store.self, from: data) { return wrapped.map }
            return nil
        }

        // 1) Exact: subdirectory + resource name (no extension in `resource`)
        if let url = bundle.url(forResource: resource, withExtension: "json", subdirectory: subdirectory),
           let data = try? Data(contentsOf: url),
           let map = decodeMap(from: data) {
            #if DEBUG
            print("PuzzleLibrary.load: loaded \(url.lastPathComponent) from subdirectory '" + subdirectory + "'")
            #endif
            return map
        }

        // 2) Root: resource.json at bundle root
        if let url = bundle.url(forResource: resource, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let map = decodeMap(from: data) {
            #if DEBUG
            print("PuzzleLibrary.load: loaded \(url.lastPathComponent) from bundle root")
            #endif
            print(map)
            return map
        }

        // 3) Legacy name: Puzzles.json at root
        if let url = bundle.url(forResource: "Puzzles", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let map = decodeMap(from: data) {
            #if DEBUG
            print("PuzzleLibrary.load: loaded legacy Puzzles.json from bundle root")
            #endif
            return map
        }

        // 4) Heuristic scan: find any puzzles.json anywhere in the bundle (handles folder references)
        if let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            if let hit = urls.first(where: { $0.lastPathComponent.lowercased() == "puzzles.json" }),
               let data = try? Data(contentsOf: hit),
               let map = decodeMap(from: data) {
                #if DEBUG
                print("PuzzleLibrary.load: loaded via scan at \(hit.path)")
                #endif
                return map
            }
            // Secondary: any JSON under a Puzzles/ directory
            if let hit = urls.first(where: { $0.path.contains("/Puzzles/") && $0.lastPathComponent.hasSuffix(".json") }),
               let data = try? Data(contentsOf: hit),
               let map = decodeMap(from: data) {
                #if DEBUG
                print("PuzzleLibrary.load: loaded from Puzzles/ via scan at \(hit.lastPathComponent)")
                #endif
                return map
            }
        }

        #if DEBUG
        let all = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil)?.map { $0.lastPathComponent } ?? []
        print("PuzzleLibrary.load: FAILED to locate puzzles.json. Tried resource='\(resource)', subdirectory='\(subdirectory)'. JSONs in bundle: \(all)")
        #endif
        return nil
    }
}


/// Represents a single cell on the 6×6 board. Encapsulates row and column
/// indices and conforms to `Hashable` and `Codable` for use in sets and
/// persistence. Using a dedicated type instead of `(Int, Int)` improves
/// type safety and allows easy extension in the future.
public struct Cell: Hashable, Codable {
    public let row: Int
    public let col: Int
    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

/// Represents a single diagonal letter sequence that the player can drag and drop onto the board.
/// Each piece has a unique identifier, an ordered collection of letters and may be placed on
/// exactly one non‑main diagonal at a time. When a piece is removed from the board its
/// `placedOn` property becomes `nil` again.
public struct GamePiece: Identifiable, Codable, Equatable {
    public let id: String
    public let letters: String
    /// The target identifier this piece is currently placed on. `nil` if it is still in the
    /// selection pane. When a piece is placed the engine assigns this property for you.
    public var placedOn: String?

    /// Compute the number of letters in the piece. This is equivalent to the length of
    /// the target diagonal that will accept the piece.
    public var length: Int {
        return letters.count
    }
}

/// Represents one of the 10 non‑main diagonals in the 6×6 board. Each target knows
/// exactly which board positions it occupies. Targets are identified by a stable string id
/// (for example "d_len3_a"), contain an ordered list of `Cell` coordinates and optionally reference
/// the id of the piece currently occupying them.
public struct GameTarget: Identifiable, Codable, Equatable {
    public let id: String
    /// Zero‑based board coordinates that this diagonal covers. The order of cells matches
    /// the order in which the letters of a piece should appear on the board.
    public let cells: [Cell]
    /// The length of the diagonal. Convenience mirror of `cells.count` so callers
    /// don’t need to compute it repeatedly.
    public let length: Int
    /// Identifier of the piece occupying this target. `nil` when the diagonal is empty.
    public var pieceId: String?

    public init(id: String, cells: [Cell], pieceId: String? = nil) {
        self.id = id
        self.cells = cells
        self.length = cells.count
        self.pieceId = pieceId
    }
}

/// Represents the main diagonal – the blue cells from the top left to bottom right.
/// Users cannot drag pieces into this diagonal. Only after all other pieces are placed
/// does the game prompt for a six letter input to fill this diagonal. The engine
/// stores the user’s letters in `value` and persists them between moves. Empty strings
/// represent unfilled cells.
public struct MainDiagonal: Codable, Equatable {
    public let cells: [Cell]
    public var value: [String]

    public init(cells: [Cell]) {
        self.cells = cells
        self.value = Array(repeating: "", count: cells.count)
    }
}

/// Complete state of the game at a point in time. This structure is fully codable and
/// is used both for persistence (saving progress) and for undo/redo snapshots.
public struct GameState: Codable, Equatable {
    /// A 6×6 matrix of strings. Empty strings represent empty cells. Each placement writes
    /// letters into this matrix. The matrix is recomputed whenever a piece is placed or
    /// removed to ensure overlapping diagonals share the same letters consistently.
    public var board: [[String]]
    /// The collection of droppable targets. Each target knows its cells and optionally
    /// the id of the occupying piece. There are always 10 targets – two per length 1–5.
    public var targets: [GameTarget]
    /// The main diagonal state. Contains the 6 cells and the letters the player entered.
    public var mainDiagonal: MainDiagonal
    /// All of the pieces currently in play. Each has an id, letters and placement status.
    public var pieces: [GamePiece]
    /// Boolean indicating whether the board has been validated to be fully correct. This flag
    /// is updated by validateBoard() when all pieces are placed and row words are valid.
    public var solved: Bool

    public init(board: [[String]], targets: [GameTarget], mainDiagonal: MainDiagonal, pieces: [GamePiece], solved: Bool = false) {
        self.board = board
        self.targets = targets
        self.mainDiagonal = mainDiagonal
        self.pieces = pieces
        self.solved = solved
    }
}

/// Encapsulates the puzzle’s configuration, including the fixed set of pieces and the list
/// of diagonals. The engine uses this configuration to initialize new games. A future
/// version of the app could load different configurations for a daily puzzle or user
/// generated puzzles.
public struct PuzzleConfiguration: Codable {
    /// All diagonals in the board. Includes the main diagonal at index 0 followed by
    /// targets in ascending order of length. The engine will keep the main diagonal
    /// separate in its state, but storing it here simplifies reconstruction.
    public let diagonals: [[Cell]]
    /// The letters used for each piece. The order matters only for generating ids.
    public let pieceLetters: [String]

    public static func defaultConfiguration() -> PuzzleConfiguration {
        // Precompute all diagonals of the 6×6 grid. The main diagonal goes first.
        // Non‑main diagonals are paired by length: two of length 1, two of length 2, ... up to 5.
        var diagonals: [[Cell]] = []
        var main: [Cell] = []
        for i in 0..<6 {
            main.append(Cell(row: i, col: i))
        }
        diagonals.append(main)
        // Non‑main diagonals. We collect all diagonals parallel to the main, above and below it.
        var diagCells: [[Cell]] = []
        // Upper diagonals (starting at row 0, increasing column)
        for offset in 1..<6 {
            var cells: [Cell] = []
            var row = 0
            var col = offset
            while row < 6 && col < 6 {
                cells.append(Cell(row: row, col: col))
                row += 1
                col += 1
            }
            diagCells.append(cells)
        }
        // Lower diagonals (starting at column 0, increasing row)
        for offset in 1..<6 {
            var cells: [Cell] = []
            var col = 0
            var row = offset
            while row < 6 && col < 6 {
                cells.append(Cell(row: row, col: col))
                row += 1
                col += 1
            }
            diagCells.append(cells)
        }
        // Sort diagonals by length and then lexicographically by start position so that
        // lengths come in ascending order (1 through 5) and within each length the first
        // diagonal is the upper one then the lower one.
        diagCells.sort { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count < rhs.count
            } else {
                // Compare by starting cell coordinates
                guard let lFirst = lhs.first else { return true }
                guard let rFirst = rhs.first else { return false }
                if lFirst.row != rFirst.row {
                    return lFirst.row < rFirst.row
                }
                return lFirst.col < rFirst.col
            }
        }
        diagonals.append(contentsOf: diagCells)
        // No default piece letters; pieces are derived from JSON-driven daily words.
        return PuzzleConfiguration(diagonals: diagonals, pieceLetters: [])
    }
}

/// Primary engine responsible for mutating the game state in response to user actions.
/// This object exposes high level methods for placing and removing pieces, typing the
/// main diagonal, validating the board and undoing/redoing operations. The engine
/// maintains its own undo and redo stacks and publishes state changes via the
/// `@Published` property so the SwiftUI layer automatically reacts to updates.
public final class GameEngine: ObservableObject {
    /// The current mutable game state. Any update to this property will trigger
    /// SwiftUI view updates.
    @Published public private(set) var state: GameState
    /// Undo history storing past states. When an operation is performed the current
    /// state is pushed onto this stack before the mutation. Calling `undo()` pops
    /// the most recent state and restores it into `state`.
    private var history: [GameState] = []
    /// Redo history storing undone states. When an operation is undone the popped
    /// state is pushed here. Performing a new operation will clear this stack.
    private var future: [GameState] = []
    /// The configuration used to generate this game. Exposed so that UI can read
    /// structural information (for example the list of targets) without duplicating
    /// logic.
    public let configuration: PuzzleConfiguration

    /// The six horizontal target words for the current puzzle (row 0..5).
    public private(set) var puzzleRowWords: [String] = []

    public init(configuration: PuzzleConfiguration = .defaultConfiguration()) {
        self.configuration = configuration
        let state = GameEngine.createInitialState(configuration: configuration)
        self.state = state
    }

    /// Loads a puzzle from a bundled JSON file (date -> [six words]).
    /// If loading fails, falls back to the provided configuration/default.
    public convenience init(puzzleDate: Date = Date(),
                             resource: String = "puzzles",
                             subdirectory: String = "Puzzles") {
        let df = DateFormatter()
        df.dateFormat = "MM/dd/yyyy"
        let key = df.string(from: puzzleDate)

        guard let library = PuzzleLibrary.load(resource: resource, subdirectory: subdirectory),
              let words = library[key] else {
            fatalError("No puzzle found for date \(key)")
        }

        // Uppercase and sanitize words to 6 letters
        let up = words.map { String($0.uppercased().prefix(6)) }

        // Build piece letters from the six words
        let base = PuzzleConfiguration.defaultConfiguration()
        let pieceLetters = PuzzleBuilder.pieceLetters(from: up)

        let config = PuzzleConfiguration(diagonals: base.diagonals, pieceLetters: pieceLetters)
        self.init(configuration: config)
        self.puzzleRowWords = up
    }

    /// Restores the engine to a previously saved state. This API allows
    /// callers (such as the view model) to assign the engine state without
    /// directly mutating the `state` property, which has a private setter. The
    /// undo and redo histories are optionally cleared and the board is
    /// recomputed to ensure consistency. This method is marked `@MainActor` to
    /// guarantee updates occur on the main thread.
    @MainActor
    public func restore(_ saved: GameState, wipeHistory: Bool = true) {
        if wipeHistory {
            history.removeAll()
            future.removeAll()
        }
        // Assign the saved state. Use the private setter by directly
        // manipulating the backing variable.
        self.state = saved
        // Recompute the board and solved flag from the restored pieces and main
        // diagonal. This ensures that any derived state (overlapping cells) is
        // consistent.
        recomputeBoard()
    }

    /// Generates the initial empty state for a given puzzle configuration. Called from
    /// the initializer and also used when resetting the game. All pieces begin
    /// unplaced, the main diagonal is empty and the board contains only empty strings.
    private static func createInitialState(configuration: PuzzleConfiguration) -> GameState {
        // Build pieces with ids "p1", "p2", ... in order of the letters provided.
        var pieces: [GamePiece] = []
        for (index, letters) in configuration.pieceLetters.enumerated() {
            let id = "p\(index + 1)"
            pieces.append(GamePiece(id: id, letters: letters, placedOn: nil))
        }
        // Build targets from diagonals (excluding main diagonal at index 0). Ids follow
        // the pattern "d_lenX_a" and "d_lenX_b" depending on ordering. We rely on
        // configuration.diagonals[1...] being sorted by length ascending and then by
        // start position such that each pair of diagonals of the same length appears
        // consecutively. For each pair we assign suffixes "a" then "b".
        var targets: [GameTarget] = []
        var currentLength: Int = 0
        var suffixChar: Character = "a"
        for diag in configuration.diagonals.dropFirst() {
            if diag.count != currentLength {
                // start a new pair
                currentLength = diag.count
                suffixChar = "a"
            }
            let id = "d_len\(currentLength)_\(suffixChar)"
            suffixChar = suffixChar == "a" ? "b" : "a"
            targets.append(GameTarget(id: id, cells: diag))
        }
        // Build main diagonal
        let mainCells = configuration.diagonals.first ?? []
        let mainDiagonal = MainDiagonal(cells: mainCells)
        // Create empty board 6×6
        let emptyRow = Array(repeating: "", count: 6)
        let board = Array(repeating: emptyRow, count: 6)
        return GameState(board: board, targets: targets, mainDiagonal: mainDiagonal, pieces: pieces)
    }

    /// Resets the puzzle to its initial empty state. Clears the undo/redo stacks.
    public func reset() {
        self.history = []
        self.future = []
        self.state = GameEngine.createInitialState(configuration: configuration)
    }

    /// Compute the list of target identifiers that can accept a given piece. A target is
    /// valid if its length matches the length of the piece. This allows targeting both
    /// empty and occupied targets of the same length for replacement.
    public func validTargets(for pieceId: String) -> [String] {
        guard let piece = state.pieces.first(where: { $0.id == pieceId }) else { return [] }
        // Allow both empty and occupied targets of the same length so we can replace
        return state.targets.filter { $0.length == piece.length }.map { $0.id }
    }

    /// Attempts to place the specified piece onto the specified target. This method
    /// validates that the target length matches the piece length, that the target is
    /// currently empty and that placing the piece would not introduce any letter
    /// conflicts. If successful the state is mutated and true is returned. Otherwise
    /// the state remains unchanged and false is returned.
    @discardableResult
    public func placePiece(pieceId: String, on targetId: String) -> Bool {
        guard let pieceIndex = state.pieces.firstIndex(where: { $0.id == pieceId }),
              let targetIndex = state.targets.firstIndex(where: { $0.id == targetId }) else {
            return false
        }
        var piece = state.pieces[pieceIndex]
        let target = state.targets[targetIndex]
        // Validate length
        guard target.length == piece.length else { return false }
        // Validate that target is empty
        guard state.targets[targetIndex].pieceId == nil else { return false }
        // Validate no conflicts with existing board letters
        for (letter, cell) in zip(piece.letters, target.cells) {
            let row = cell.row
            let col = cell.col
            let existing = state.board[row][col]
            if !existing.isEmpty && existing != String(letter) {
                // conflict
                return false
            }
        }
        // Snapshot current state for undo
        history.append(state)
        future.removeAll()
        // Commit placement: mark piece placed on target, assign target's pieceId
        piece.placedOn = target.id
        state.pieces[pieceIndex] = piece
        state.targets[targetIndex].pieceId = piece.id
        // Recompute the board from scratch
        recomputeBoard()
        return true
    }

    /// Places the specified piece on the target. If the target is occupied by another
    /// piece of the same length, it replaces it (the previous piece returns to the pane).
    /// Returns a tuple (success, replacedPieceId) where replacedPieceId is non-nil only
    /// when a replacement occurred.
    @discardableResult
    public func placeOrReplace(pieceId: String, on targetId: String) -> (Bool, String?) {
        guard let pieceIndex = state.pieces.firstIndex(where: { $0.id == pieceId }),
              let targetIndex = state.targets.firstIndex(where: { $0.id == targetId }) else {
            return (false, nil)
        }
        var piece = state.pieces[pieceIndex]
        let target = state.targets[targetIndex]
        // Validate length
        guard target.length == piece.length else { return (false, nil) }

        // Build a temporary board that excludes the current target's letters so we can
        // validate conflicts against other placements only.
        var tempBoard = Array(repeating: Array(repeating: "", count: 6), count: 6)
        for t in state.targets {
            guard t.id != target.id, let pid = t.pieceId, let p = state.pieces.first(where: { $0.id == pid }) else { continue }
            for (ch, cell) in zip(p.letters, t.cells) {
                tempBoard[cell.row][cell.col] = String(ch)
            }
        }
        // Also include the main diagonal letters in conflict checking
        for (letter, cell) in zip(state.mainDiagonal.value, state.mainDiagonal.cells) {
            tempBoard[cell.row][cell.col] = letter
        }
        // Validate no conflicts against tempBoard
        for (letter, cell) in zip(piece.letters, target.cells) {
            let existing = tempBoard[cell.row][cell.col]
            if !existing.isEmpty && existing != String(letter) {
                return (false, nil)
            }
        }

        // Snapshot for undo and clear redo
        history.append(state)
        future.removeAll()

        // If occupied, unplace the previous piece
        var replacedId: String? = nil
        if let occupiedId = state.targets[targetIndex].pieceId,
           let occupiedIndex = state.pieces.firstIndex(where: { $0.id == occupiedId }) {
            state.pieces[occupiedIndex].placedOn = nil
            replacedId = occupiedId
        }

        // Commit placement
        piece.placedOn = target.id
        state.pieces[pieceIndex] = piece
        state.targets[targetIndex].pieceId = piece.id

        // Recompute board and solved flag
        recomputeBoard()
        return (true, replacedId)
    }

    /// Removes the piece occupying the specified target, if any. Returns the id of the
    /// removed piece or `nil` if the target was already empty. The board is recomputed
    /// after the removal to ensure overlapping diagonals remain intact.
    @discardableResult
    public func removePiece(from targetId: String) -> String? {
        print("removePiece(from: \(targetId))")
        guard let targetIndex = state.targets.firstIndex(where: { $0.id == targetId }),
              let pieceId = state.targets[targetIndex].pieceId,
              let pieceIndex = state.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return nil
        }
        // Snapshot current state for undo
        history.append(state)
        future.removeAll()
        // Clear the piece placement
        state.targets[targetIndex].pieceId = nil
        state.pieces[pieceIndex].placedOn = nil
        // Recompute the board
        recomputeBoard()
        return pieceId
    }

    /// Records the six letters entered by the user into the main diagonal. This method
    /// overwrites any previous main diagonal content. To modify individual letters
    /// prefer calling this method with the entire six letter array. The board is
    /// recomputed afterwards.
    public func setMainDiagonal(_ letters: [String]) {
        guard letters.count == state.mainDiagonal.cells.count else { return }
        history.append(state)
        future.removeAll()
        state.mainDiagonal.value = letters
        // Recompute board because the main diagonal has changed
        recomputeBoard()
    }

    /// Rebuilds the 6×6 board from the current piece placements and main diagonal. This
    /// function clears the board to empty strings then writes each piece’s letters and
    /// the main diagonal letters back into the matrix. Overlapping letters must
    /// necessarily match because `placePiece` checks for conflicts up front.
    private func recomputeBoard() {
        // Reset all cells
        var newBoard = Array(repeating: Array(repeating: "", count: 6), count: 6)
        // Write pieces
        for target in state.targets {
            guard let pieceId = target.pieceId,
                  let piece = state.pieces.first(where: { $0.id == pieceId }) else {
                continue
            }
            for (letter, cell) in zip(piece.letters, target.cells) {
                let row = cell.row
                let col = cell.col
                newBoard[row][col] = String(letter)
            }
        }
        // Write main diagonal letters
        for (letter, cell) in zip(state.mainDiagonal.value, state.mainDiagonal.cells) {
            let row = cell.row
            let col = cell.col
            newBoard[row][col] = letter
        }
        state.board = newBoard
        // Mark solved flag if all pieces placed and rows form valid words
        state.solved = isSolved()
    }
    
    // MARK: - Tap Helpers
    public func occupiedTargetId(containing cell: Cell) -> String? {
        // We only look at non-main diagonals (targets). If a target is occupied and
        // includes the tapped cell, return that target id; otherwise nil.
        for target in state.targets where target.pieceId != nil {
            if target.cells.contains(cell) {
                return target.id
            }
        }
        return nil
    }

    /// Determines if the puzzle is complete: all pieces placed, main diagonal filled,
    /// and every horizontal word matches the loaded puzzle words.
    private func isSolved() -> Bool {
        // All targets must be occupied and main diagonal fully filled
        let allPlaced = state.targets.allSatisfy { $0.pieceId != nil }
        let mainFilled = state.mainDiagonal.value.allSatisfy { !$0.isEmpty }
        guard allPlaced && mainFilled else { return false }
        // If we have six target words, require exact row matches (case-insensitive)
        if puzzleRowWords.count == 6 {
            for row in 0..<6 {
                let word = state.board[row].joined().uppercased()
                if word != puzzleRowWords[row].uppercased() { return false }
            }
            return true
        }
        // Without a loaded word list, treat as unsolved to avoid false positives
        return false
    }

    // no longer used for validation
    /// Spell checks the provided word using the system dictionary. Returns true when the
    /// word contains no spelling errors. `UITextChecker` is available on iOS and
    /// provides access to the platform dictionary. If for some reason spell checking
    /// fails the word is considered invalid to avoid false positives.
    private static func isValidWord(_ word: String) -> Bool {
        let checker = UITextChecker()
        let nsWord = word as NSString
        let range = NSRange(location: 0, length: nsWord.length)
        let misspelledRange = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en_US")
        return misspelledRange.location == NSNotFound
    }

    /// Undo the most recent operation. Restores the last state from the history stack
    /// and pushes the current state onto the redo stack. Returns true if an undo
    /// occurred or false if there is no history to revert.
    @discardableResult
    public func undo() -> Bool {
        guard let previous = history.popLast() else { return false }
        future.append(state)
        state = previous
        return true
    }

    /// Redo the most recently undone operation. Pops the last state off the redo stack
    /// and pushes the current state onto the undo stack. Returns true if a redo
    /// occurred or false if there is no future state to restore.
    @discardableResult
    public func redo() -> Bool {
        guard let next = future.popLast() else { return false }
        history.append(state)
        state = next
        return true
    }
}
