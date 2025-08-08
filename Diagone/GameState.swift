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

    /// The canonical list of letter sequences used to seed the
    /// draggable pieces. By default this is the demo set used in the
    /// original version of the game. When a puzzle is loaded from
    /// JSON this array is replaced by the sequences derived from the
    /// selected puzzle.
    private var currentSequences: [String] = [
        "M", "E", "RA", "SE", "ALD", "WEN",
        "FAGI", "RBEY", "RAYAA", "HBLAN"
    ]

    /// The expected six row words for the currently loaded puzzle.
    /// This array is empty when no puzzle is loaded. Words are
    /// uppercased for consistent comparison.
    private(set) var answerRows: [String] = []

    /// The expected diagonal word for the currently loaded puzzle.
    /// It is uppercased for consistent comparison.
    private(set) var answerDiagonal: String = ""

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

    // MARK: - Puzzle loading

    /// Computes the ten diagonal letter sequences for a puzzle from
    /// the supplied row words. The mapping follows the specification:
    ///
    /// - Sequence 0: first letter of row 6
    /// - Sequence 1: sixth letter of row 1
    /// - Sequence 2: first letter of row 5 + second letter of row 6
    /// - Sequence 3: fifth letter of row 1 + sixth letter of row 2
    /// - Sequence 4: fourth letter of row 1 + fifth letter of row 2 + fourth letter of row 3
    /// - Sequence 5: first letter of row 4 + second letter of row 5 + third letter of row 4
    /// - Sequence 6: first letter of row 3 + second letter of row 4 + third letter of row 5 + fourth letter of row 6
    /// - Sequence 7: third letter of row 1 + fourth letter of row 2 + fifth letter of row 3 + sixth letter of row 4
    /// - Sequence 8: first letter of row 2 + second letter of row 3 + third letter of row 4 + fourth letter of row 5 + fifth letter of row 6
    /// - Sequence 9: second letter of row 1 + third letter of row 2 + fourth letter of row 3 + fifth letter of row 4 + sixth letter of row 5
    ///
    /// - Parameter rows: An array of six uppercase words representing the
    ///   target rows. Indices are assumed to be valid (i.e. each word
    ///   has at least six characters).
    /// - Returns: An array of ten letter sequences corresponding to the
    ///   diagonals.
    private func computeSequences(from rows: [String]) -> [String] {
        guard rows.count == 6 else { return currentSequences }
        // Convert all rows to arrays of characters for easier indexing
        let r = rows.map { Array($0.uppercased()) }
        var sequences: [String] = []
        // 0
        sequences.append(String(r[5][0]))
        // 1
        sequences.append(String(r[0][5]))
        // 2
        sequences.append(String(r[4][0]) + String(r[5][1]))
        // 3
        sequences.append(String(r[0][4]) + String(r[1][5]))
        // 4
        sequences.append(String(r[3][0]) + String(r[4][1]) + String(r[5][2]))
        // 5
        sequences.append(String(r[0][3]) + String(r[1][4]) + String(r[2][5]))
        // 6
        sequences.append(String(r[2][0]) + String(r[3][1]) + String(r[4][2]) + String(r[5][3]))
        // 7
        sequences.append(String(r[0][2]) + String(r[1][3]) + String(r[2][4]) + String(r[3][5]))
        // 8
        sequences.append(String(r[1][0]) + String(r[2][1]) + String(r[3][2]) + String(r[4][3]) + String(r[5][4]))
        // 9
        sequences.append(String(r[0][1]) + String(r[1][2]) + String(r[2][3]) + String(r[3][4]) + String(r[4][5]))
        return sequences
    }

    /// Loads puzzles from a JSON file named `puzzles.json` located in
    /// the `Puzzles` directory at the app's bundle root. The JSON
    /// format should map puzzle names to an array of seven uppercase
    /// words: the first six are row words and the seventh is the
    /// diagonal word. If a `puzzleName` is supplied the puzzle with
    /// that key is selected; otherwise the first entry is used.
    ///
    /// After loading, this method sets `answerRows`, `answerDiagonal`
    /// and updates `currentSequences` based on the row words. It then
    /// resets the game state to initialise the board and pieces with
    /// the new puzzle.
    func loadPuzzle(named puzzleName: String? = nil) {
        let fm = FileManager.default
        var url: URL?

        // 1) Most common: file is copied to bundle root (flattened)
        if let u = Bundle.main.url(forResource: "puzzles", withExtension: "json") {
            url = u
        }
        // 2) If you added a *Folder Reference* (blue folder) called "Puzzles"
        else if let u = Bundle.main.url(forResource: "puzzles", withExtension: "json", subdirectory: "Puzzles") {
            url = u
        }
        // 3) Last resort: scan bundle for any puzzles.json (handles odd project setups)
        else if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil),
                let u = urls.first(where: { $0.lastPathComponent.lowercased() == "puzzles.json" }) {
            url = u
        }

        // (Optional) Keep your dev/test fallbacks for unit tests on macOS
        if url == nil {
            let cwd = fm.currentDirectoryPath
            let p1 = URL(fileURLWithPath: cwd).appendingPathComponent("Puzzles/puzzles.json")
            let p2 = URL(fileURLWithPath: cwd).appendingPathComponent("Diagone/Puzzles/puzzles.json")
            if fm.fileExists(atPath: p1.path) { url = p1 }
            else if fm.fileExists(atPath: p2.path) { url = p2 }
        }

        guard let fileUrl = url else {
            print("puzzles.json not found in app bundle. Check Target Membership / Copy Bundle Resources.")
            return
        }

        do {
            let data = try Data(contentsOf: fileUrl)
            // Decode as [String: [String]] dictionary. Accept both
            // single-quoted and double-quoted JSON by replacing single
            // quotes before decoding.
            let jsonString = String(decoding: data, as: UTF8.self)
            // Replace single quotes with double quotes for valid JSON
            let normalized = jsonString.replacingOccurrences(of: "'", with: "\"")
            guard let normalizedData = normalized.data(using: .utf8) else { return }
            let decoder = JSONDecoder()
            let puzzles = try decoder.decode([String: [String]].self, from: normalizedData)
            // Select puzzle
            let key: String
            if let name = puzzleName, puzzles.keys.contains(name) {
                key = name
            } else if let firstKey = puzzles.keys.first {
                key = firstKey
            } else {
                return
            }
            guard let words = puzzles[key], words.count >= 7 else { return }
            // Assign answer rows and diagonal word
            let rows = Array(words[0..<6]).map { $0.uppercased() }
            answerRows = rows
            answerDiagonal = words[6].uppercased()
            print("answerRows", answerRows)
            print("answerDiagonal", answerDiagonal)
            // Compute new sequences from the rows
            currentSequences = computeSequences(from: rows)
            // Reset the game state to apply the new sequences and clear
            // any existing placements. Do not start a timer here.
            resetGame()
        } catch {
            // If loading fails, silently ignore and retain defaults
            return
        }
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
        // Use the currentSequences array to seed pieces. This allows
        // puzzles loaded from JSON to override the default sequences.
        pieces = currentSequences.map { seq in
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

        // Write values onto the board immediately
        for i in 0..<6 {
            let letter = values[i].uppercased()
            board[i][i] = letter
            mainDiagonal[i] = letter
        }

        // Defer validation so the last keystroke is registered in the UI/state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.checkAllRowsValid() {
                self.isGameWon = true
                self.message = nil
                self.stopTimer()
            } else {
                // Revert only the main diagonal on failure
                for i in 0..<6 {
                    self.board[i][i] = nil
                    self.mainDiagonal[i] = nil
                }
                self.isGameWon = false
                self.message = "Incorrect solution. Please try again."
                // timer keeps running
            }
        }
    }


    /// Strictly validates the board against the loaded puzzle:
    /// - All 6 rows must equal `answerRows[0...5]`
    /// - Main diagonal must equal `answerDiagonal`
    /// - Every non-main diagonal must match letters implied by the rows
    /// Any deviation returns false.
    private func checkAllRowsValid() -> Bool {
        // Must have a loaded puzzle
        guard !answerRows.isEmpty, !answerDiagonal.isEmpty else {
            print("test0")
            return false
        }
        // Normalize expected answers once
        let rowsU = answerRows.map { $0.uppercased() }
        let diagU = answerDiagonal.uppercased()

        // Sanity: each row must have at least 6 chars
        guard rowsU.count == 6, rowsU.allSatisfy({ $0.count >= 6 }) else {
            print("Guard 1")
            return false
        }

        // ---- Rows must match exactly
        for r in 0..<6 {
            var word = ""
            for c in 0..<6 {
                guard let ch = board[r][c] else {
                    print("Guard 2")
                    return false
                }
                word += ch
            }
            if word.uppercased() != rowsU[r] {
                print(word, "!=",  rowsU[r])
                return false
            }
        }

        // ---- Main diagonal must match exactly
        var main = ""
        for i in 0..<6 {
            guard let ch = board[i][i] else {
                print("Guard 3")
                return false
            }
            main += ch
        }
        if main.uppercased() != diagU {
            print(main, "!=",  diagU)
            return false
        }

        // ---- Every non-main diagonal must match the letters implied by rows
        // Build quick-access char arrays for expected rows (ASCII A–Z assumed)
        let rowChars: [[Character]] = rowsU.map { Array($0) }

        for target in targets { // targets are non-main diagonals by construction
            var placed = ""
            var expected = ""
            for cell in target.cells {
                guard let ch = board[cell.row][cell.col] else {
                    print("Guard 4")
                    return false
                }
                placed += ch.uppercased()
                // expected letter is simply the one at (row, col) in the answer rows
                expected.append(rowChars[cell.row][cell.col])
            }
            if placed != String(expected) {
                print(placed, "!=", String(expected))
                return false
            }
        }

        return true
    }

}
