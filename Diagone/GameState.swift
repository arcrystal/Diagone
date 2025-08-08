import Foundation
import UIKit

/// The core state model for the Diagone game. This class manages the
/// board contents, the list of diagonals, available pieces, and handles
/// placement, removal and validation of moves. Published properties
/// notify SwiftUI views about changes so that the UI stays in sync.
final class GameState: ObservableObject {

    // MARK: - Published properties

    /// A 6×6 grid holding the currently placed letters. Empty cells
    /// contain `nil` rather than an empty string to differentiate between
    /// unpopulated and intentionally blank values.
    @Published var board: [[String?]] = Array(
        repeating: Array(repeating: nil, count: 6), count: 6
    )

    /// The list of all non‑main diagonals. Each diagonal knows which
    /// cells it spans and whether a piece is currently occupying it.
    @Published var targets: [DiagonalTarget] = []

    /// The collection of draggable pieces available for placement.
    @Published var pieces: [GamePiece] = []

    /// The six values entered on the main diagonal by the player. Each
    /// element is either `nil` (before input) or a single uppercase
    /// character. When all ten pieces are placed this becomes editable.
    @Published var mainDiagonal: [String?] = Array(repeating: nil, count: 6)

    /// When `true` a main diagonal input UI should be shown. This is
    /// triggered automatically once all pieces have been placed.
    @Published var showMainInput: Bool = false

    /// Flag indicating that the puzzle has been solved correctly. This
    /// can be observed by the UI to show a celebratory message.
    @Published var isGameWon: Bool = false

    /// The number of seconds elapsed since the current puzzle started.
    /// When the timer is not running this will remain at 0. The UI can
    /// display this value to the player. It updates once per second
    /// while the game is active.
    @Published var elapsedSeconds: Int = 0

    /// Indicates whether a puzzle has been started. This flag can be
    /// observed by the UI to enable/disable controls such as the start
    /// button or reset the board. It becomes true after calling
    /// `startTimer()` and false again when the game is reset.
    @Published var puzzleStarted: Bool = false

    /// A transient message describing the most recent error (e.g. a
    /// conflict or invalid row). The UI may display this to the user.
    @Published var message: String? = nil

    // MARK: - Timer state

    /// The date at which the current puzzle was started. When nil the
    /// timer is not running. Used together with `elapsedSeconds` to
    /// calculate the elapsed time. Not published because UI should
    /// instead observe `elapsedSeconds`.
    private var startDate: Date? = nil

    /// A repeating timer updating the elapsed seconds. When non‑nil
    /// the timer fires every second, incrementing `elapsedSeconds`. It
    /// is automatically invalidated when the game resets or finishes.
    private var timer: Timer? = nil

    // MARK: - Non‑published state

    /// A lookup table mapping a board cell to the id of the diagonal it
    /// belongs to, or `nil` if the cell lies on the main diagonal.
    private(set) var cellToTarget: [CellCoordinate: String?] = [:]

    // MARK: - Initialization

    /// Creates a new game state populated with diagonals and pieces. The
    /// pieces are seeded with predictable letters but could be extended
    /// to incorporate a daily puzzle generator. After initialization the
    /// board is empty and ready for play.
    init() {
        configureDiagonals()
        configurePieces()
        buildCellMapping()
    }

    // MARK: - Timer control

    /// Begins a new timer and marks the puzzle as started. If a timer
    /// is already running it will be cancelled before starting a new
    /// one. The game state is not reset automatically; callers should
    /// call `resetGame()` first if they wish to start a fresh puzzle.
    func startTimer() {
        // Cancel any existing timer
        timer?.invalidate()
        timer = nil
        startDate = Date()
        elapsedSeconds = 0
        puzzleStarted = true
        // Schedule a repeating timer on the main run loop to update
        // elapsed seconds. Use a weak self capture to avoid retaining
        // the timer strongly.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let strongSelf = self, let start = strongSelf.startDate else { return }
            // Compute the number of whole seconds since the start date
            let delta = Int(Date().timeIntervalSince(start))
            if delta >= 0 {
                strongSelf.elapsedSeconds = delta
            }
        }
    }

    /// Stops the running timer if there is one. This is called
    /// automatically when the puzzle is solved or reset. It sets
    /// `puzzleStarted` back to false and leaves `elapsedSeconds` with
    /// the final value so the player can see their time.
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        startDate = nil
        puzzleStarted = false
    }

    // MARK: - Game reset

    /// Resets the game state to its initial configuration. This clears
    /// the board, reinitialises pieces and diagonals, hides the main
    /// input and clears any messages or win state. Any running timer
    /// will be stopped and elapsed time reset. This method can be
    /// called to start over without recreating the GameState instance.
    func resetGame() {
        // Cancel any active timer and clear elapsed time
        stopTimer()
        elapsedSeconds = 0
        // Reset core data structures
        board = Array(repeating: Array(repeating: nil, count: 6), count: 6)
        configureDiagonals()
        configurePieces()
        buildCellMapping()
        // Clear main diagonal values
        mainDiagonal = Array(repeating: nil, count: 6)
        showMainInput = false
        isGameWon = false
        message = nil
    }

    // MARK: - Setup helpers

    /// Generates the 10 non‑main diagonals according to the puzzle rules.
    /// These diagonals are fixed for a 6×6 grid and are generated in a
    /// deterministic order matching the specification. The ids follow
    /// the pattern "d_lenX_a" or "d_lenX_b".
    private func configureDiagonals() {
        // Helper to build a diagonal from a list of coordinates
        func diag(id: String, _ coords: [(Int, Int)]) -> DiagonalTarget {
            let cells = coords.map { CellCoordinate(row: $0.0, col: $0.1) }
            return DiagonalTarget(id: id, cells: cells, pieceId: nil)
        }
        var d: [DiagonalTarget] = []
        // Length 1 diagonals
        d.append(diag(id: "d_len1_a", [ (0,5) ]))
        d.append(diag(id: "d_len1_b", [ (5,0) ]))
        // Length 2 diagonals
        d.append(diag(id: "d_len2_a", [ (0,4),(1,5) ]))
        d.append(diag(id: "d_len2_b", [ (4,0),(5,1) ]))
        // Length 3 diagonals
        d.append(diag(id: "d_len3_a", [ (0,3),(1,4),(2,5) ]))
        d.append(diag(id: "d_len3_b", [ (3,0),(4,1),(5,2) ]))
        // Length 4 diagonals
        d.append(diag(id: "d_len4_a", [ (0,2),(1,3),(2,4),(3,5) ]))
        d.append(diag(id: "d_len4_b", [ (2,0),(3,1),(4,2),(5,3) ]))
        // Length 5 diagonals
        d.append(diag(id: "d_len5_a", [ (0,1),(1,2),(2,3),(3,4),(4,5) ]))
        d.append(diag(id: "d_len5_b", [ (1,0),(2,1),(3,2),(4,3),(5,4) ]))
        targets = d
    }

    /// Seeds the ten draggable pieces with predetermined letter sequences.
    /// In a full implementation these could be randomized or loaded from
    /// a puzzle generator. The letters here form a simple set for
    /// demonstration and testing.
    private func configurePieces() {
        let sequences: [String] = [
            "M", "E", "RA", "SE", "ALD", "WEN",
            "FAGI", "RBEY", "RAYAA", "HBLAN"
        ]
        pieces = sequences.map { seq in
            GamePiece(id: UUID(), letters: seq, placedTargetId: nil)
        }
    }

    /// Builds a mapping from every cell to its associated diagonal. This
    /// facilitates quick lookups when tapping on the board to determine
    /// which diagonal (if any) should be interacted with.
    private func buildCellMapping() {
        for target in targets {
            for cell in target.cells {
                cellToTarget[cell] = target.id
            }
        }
        // For main diagonal cells, explicitly mark with nil
        for i in 0..<6 {
            let mainCell = CellCoordinate(row: i, col: i)
            cellToTarget[mainCell] = nil
        }
    }

    // MARK: - Game actions

    /// Attempts to place a piece on a given diagonal. Placement will fail
    /// if the piece has already been placed, if the lengths do not match
    /// or if there is a letter collision with existing board contents.
    ///
    /// - Parameters:
    ///   - pieceId: The unique identifier of the piece to place.
    ///   - targetId: The identifier of the target diagonal on which
    ///     placement is desired.
    func placePiece(pieceId: UUID, on targetId: String) {
        // Look up the piece and target indices
        guard let pieceIndex = pieces.firstIndex(where: { $0.id == pieceId }),
              let targetIndex = targets.firstIndex(where: { $0.id == targetId }) else {
            message = "Invalid selection."
            return
        }

        var piece = pieces[pieceIndex]
        var target = targets[targetIndex]

        // Ensure the piece is not already placed
        guard piece.placedTargetId == nil else {
            message = "Piece is already placed."
            return
        }

        // Ensure the piece length matches the diagonal length
        guard piece.length == target.length else {
            message = "Length mismatch."
            return
        }

        // Check for collisions
        for (idx, cell) in target.cells.enumerated() {
            let letterIdx = piece.letters.index(piece.letters.startIndex, offsetBy: idx)
            let letter = String(piece.letters[letterIdx]).uppercased()
            if let existing = board[cell.row][cell.col] {
                if existing != letter {
                    message = "Conflicting letter at row \(cell.row + 1), col \(cell.col + 1)."
                    return
                }
            }
        }

        // Commit the placement
        for (idx, cell) in target.cells.enumerated() {
            let letterIdx = piece.letters.index(piece.letters.startIndex, offsetBy: idx)
            let letter = String(piece.letters[letterIdx]).uppercased()
            board[cell.row][cell.col] = letter
        }
        piece.placedTargetId = targetId
        target.pieceId = pieceId
        pieces[pieceIndex] = piece
        targets[targetIndex] = target
        message = nil

        // If every piece is placed then enable main diagonal entry
        if pieces.allSatisfy({ $0.placedTargetId != nil }) {
            showMainInput = true
        }
    }

    /// Removes the piece occupying the given diagonal. This is called
    /// when the user taps on a placed diagonal to return the piece to
    /// the panel. All letters on the diagonal are cleared and the piece
    /// marked as unplaced. If the main diagonal input has started it
    /// will be hidden until all pieces are placed again.
    ///
    /// - Parameter targetId: The identifier of the diagonal to clear.
    func removePiece(targetId: String) {
        guard let targetIndex = targets.firstIndex(where: { $0.id == targetId }),
              let pieceId = targets[targetIndex].pieceId else {
            return
        }
        var target = targets[targetIndex]
        // Clear letters from the board
        for cell in target.cells {
            board[cell.row][cell.col] = nil
        }
        // Mark the piece as unplaced
        if let pieceIndex = pieces.firstIndex(where: { $0.id == pieceId }) {
            var piece = pieces[pieceIndex]
            piece.placedTargetId = nil
            pieces[pieceIndex] = piece
        }
        target.pieceId = nil
        targets[targetIndex] = target
        showMainInput = false
        message = nil
    }

    /// Processes the six letters entered into the main diagonal by the
    /// player. Once invoked the letters are written onto the board and
    /// each row is validated as a real word using `UITextChecker`.
    /// Upon success the `isGameWon` flag is set; otherwise an error
    /// message is recorded and the input is cleared.
    ///
    /// - Parameter values: An array of six uppercase letters.
    func setMainDiagonal(values: [String]) {
        guard values.count == 6 else { return }
        // Write values onto the board
        for i in 0..<6 {
            let letter = values[i].uppercased()
            board[i][i] = letter
            mainDiagonal[i] = letter
        }
        // Validate each row
        if checkAllRowsValid() {
            // Successful completion: mark win and stop the timer
            isGameWon = true
            message = nil
            stopTimer()
        } else {
            // Reset main diagonal cells to empty and clear values
            for i in 0..<6 {
                board[i][i] = nil
                mainDiagonal[i] = nil
            }
            isGameWon = false
            // Provide a clear failure message and stop the timer so the
            // player can see how long the incorrect attempt took.
            message = "Incorrect solution. Please try again."
            stopTimer()
        }
    }

    /// Validates that all six rows currently on the board form real
    /// English words. Any empty cell will cause validation to fail.
    /// This uses `UITextChecker` which relies on the system dictionary.
    private func checkAllRowsValid() -> Bool {
        for row in 0..<6 {
            var word = ""
            for col in 0..<6 {
                guard let letter = board[row][col] else { return false }
                word += letter
            }
            if !isRealWord(word: word) {
                return false
            }
        }
        return true
    }

    /// Determines whether the supplied string is a valid English word
    /// according to `UITextChecker`. An empty or one‑character word
    /// always returns false to avoid trivial matches.
    ///
    /// - Parameter word: A word to validate.
    /// - Returns: `true` if the word is recognised as correctly
    ///   spelled, otherwise `false`.
    func isRealWord(word: String) -> Bool {
        guard word.count > 1 else { return false }
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: "en"
        )
        return misspelledRange.location == NSNotFound
    }
}
