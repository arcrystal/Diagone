import Foundation

/// Represents a RhymeAGrams puzzle
public struct RhymeAGramsPuzzle: Codable {
    public let letters: [String]  // Pyramid letters: 1 letter, 3 letters, 5 letters, 7 letters
    public let solutions: [String]  // The four 4-letter words

    public init(letters: [String], solutions: [String]) {
        precondition(letters.count == 4, "Must have 4 rows")
        precondition(letters[0].count == 1, "Row 1 must have 1 letter")
        precondition(letters[1].count == 3, "Row 2 must have 3 letters")
        precondition(letters[2].count == 5, "Row 3 must have 5 letters")
        precondition(letters[3].count == 7, "Row 4 must have 7 letters")
        precondition(solutions.count == 4, "Must have 4 solutions")
        precondition(solutions.allSatisfy { $0.count == 4 }, "All solutions must be 4 letters")

        self.letters = letters.map { $0.uppercased() }
        self.solutions = solutions.map { $0.uppercased() }
    }
}

/// Game state for RhymeAGrams
struct RhymeAGramsState: Codable {
    var answers: [String]  // User's four answers
    var selectedSlot: Int  // Which answer slot is currently selected (0-3)

    init() {
        self.answers = ["", "", "", ""]
        self.selectedSlot = 0
    }

    mutating func setAnswer(at index: Int, to value: String) {
        guard index >= 0 && index < 4 else { return }
        answers[index] = value.uppercased().prefix(4).map(String.init).joined()
    }

    mutating func appendLetter(_ letter: String, to index: Int) {
        guard index >= 0 && index < 4 else { return }
        let current = answers[index]
        if current.count < 4 {
            answers[index] = current + letter.uppercased()
        }
    }

    mutating func deleteLetter(from index: Int) {
        guard index >= 0 && index < 4 else { return }
        if !answers[index].isEmpty {
            answers[index] = String(answers[index].dropLast())
        }
    }
}

/// RhymeAGrams game engine
class RhymeAGramsEngine {
    let puzzle: RhymeAGramsPuzzle
    private(set) var state: RhymeAGramsState

    init(puzzle: RhymeAGramsPuzzle) {
        self.puzzle = puzzle
        self.state = RhymeAGramsState()
    }

    init(puzzle: RhymeAGramsPuzzle, state: RhymeAGramsState) {
        self.puzzle = puzzle
        self.state = state
    }

    func updateAnswer(at index: Int, to value: String) {
        state.setAnswer(at: index, to: value)
    }

    func appendLetter(_ letter: String) {
        state.appendLetter(letter, to: state.selectedSlot)
    }

    func deleteLetter() {
        state.deleteLetter(from: state.selectedSlot)
    }

    func selectSlot(_ index: Int) {
        guard index >= 0 && index < 4 else { return }
        state.selectedSlot = index
    }

    /// Check if the puzzle is solved (all answers match solutions, order doesn't matter)
    var isSolved: Bool {
        let userAnswers = Set(state.answers.filter { $0.count == 4 })
        let solutionSet = Set(puzzle.solutions)
        return userAnswers == solutionSet && userAnswers.count == 4
    }

    /// Get indices of correct answers
    var correctAnswerIndices: Set<Int> {
        var correct = Set<Int>()
        let solutionSet = Set(puzzle.solutions)
        for (index, answer) in state.answers.enumerated() {
            if answer.count == 4 && solutionSet.contains(answer) {
                correct.insert(index)
            }
        }
        return correct
    }
}

/// Puzzle library for RhymeAGrams
enum RhymeAGramsPuzzleLibrary {
    struct PuzzleData: Decodable {
        let letters: [String]
        let solutions: [String]
    }

    /// Loads puzzles from JSON file mapping "MM/DD/YYYY" -> puzzle data
    static func loadPuzzleMap(resource: String = "rhymeagrams_puzzles", subdirectory: String? = nil) -> [String: PuzzleData]? {
        let bundle = Bundle.main

        // Try to load with specific name (avoids conflict with Diagone's puzzles.json)
        if let url = bundle.url(forResource: resource, withExtension: "json", subdirectory: subdirectory),
           let data = try? Data(contentsOf: url),
           let map = try? JSONDecoder().decode([String: PuzzleData].self, from: data) {
            return map
        }

        // Fallback: try root
        if let url = bundle.url(forResource: resource, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let map = try? JSONDecoder().decode([String: PuzzleData].self, from: data) {
            return map
        }

        return nil
    }

    static func loadPuzzle(for date: Date) -> RhymeAGramsPuzzle {
        // Format date as MM/DD/YYYY
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateKey = formatter.string(from: date)

        // Load puzzle map
        if let puzzleMap = loadPuzzleMap(),
           let puzzleData = puzzleMap[dateKey] {
            return RhymeAGramsPuzzle(
                letters: puzzleData.letters,
                solutions: puzzleData.solutions
            )
        }

        // Fallback to default puzzle if date not found
        return RhymeAGramsPuzzle(
            letters: ["B", "EEE", "EHIII", "IKKKKLP"],
            solutions: ["BIKE", "HIKE", "LIKE", "PIKE"]
        )
    }
}
