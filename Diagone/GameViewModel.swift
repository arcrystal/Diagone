import Foundation
import SwiftUI
import Combine

/// View model bridging the game engine and the SwiftUI layer. Exposes high level
/// operations that the UI can call in response to user gestures and binds engine
/// state to published properties for reactive updates. This object also manages
/// UI concerns such as the timer, drag hover feedback and confetti triggers.
@MainActor
public final class GameViewModel: ObservableObject {
    /// The underlying engine that implements the game rules.
    /// All mutations of the board go through this engine.
    @Published private(set) var engine: GameEngine
    /// Whether the user has pressed the start button.
    /// Chips remain hidden until this flag becomes true.
    @Published public var started: Bool = false
    @Published public var finished: Bool = false
    /// The currently highlighted drop target id while dragging.
    /// The board view observes this to highlight matching diagonals during drag and drop.
    @Published public var dragHoverTargetId: String? = nil
    /// Whether to present the six cell input field for entering the main diagonal.
    /// This becomes true after all pieces are placed.
    @Published public var showMainInput: Bool = false
    /// Whether to present confetti animation overlay after winning the puzzle.
    @Published public var showConfetti: Bool = false
    /// Elapsed time in seconds since the player pressed start. Updates every
    /// second while playing.
    @Published public var elapsedTime: TimeInterval = 0
    @Published public var finishTime: TimeInterval = 0
    /// The letters entered into the six cells of the main diagonal input. When
    /// changed the view model writes these letters into the engine’s state.
    @Published public var mainInput: [String] = Array(repeating: "", count: 6)

    /// The identifier of the piece currently being dragged from the panel. When
    /// non‑nil the board highlights only those diagonals whose lengths match
    /// the dragged piece and are available. Cleared when the drag completes.
    @Published public var draggingPieceId: String? = nil

    /// The global screen coordinates of the current drag location. Updated by
    /// the chip's `DragGesture` on every movement. The board uses this to
    /// calculate which diagonal the user is hovering over.
    @Published public var dragGlobalLocation: CGPoint? = nil

    /// The frame of the board in global coordinates. This is set by the
    /// `BoardView` via a `GeometryReader` so that drag positions can be
    /// converted into board space when determining hover state. It will be
    /// `.zero` until the board appears on screen.
    @Published public var boardFrameGlobal: CGRect = .zero

    private var timerCancellable: AnyCancellable?
    private var startDate: Date?
    private let storageKey = "diagone_state"

    public init(engine: GameEngine = GameEngine()) {
        self.engine = engine
        // Try to restore from saved progress
        if let restored = Self.loadSavedState(for: engine.configuration) {
            // Restore must go through the engine to recompute board and clear
            // history. Use a dedicated restore API so that state invariants are
            // maintained.
            engine.restore(restored)
            // Determine if the main input should be visible based on number of placed pieces
            let allPlaced = engine.state.targets.allSatisfy { $0.pieceId != nil }
            self.showMainInput = allPlaced
            self.mainInput = engine.state.mainDiagonal.value
        }
    }

    /// Starts the timer and reveals the puzzle. Chips become draggable only after
    /// calling this method. If the puzzle had been reset previously the timer will
    /// restart from zero.
    public func startGame() {
        guard !started else { return }
        showMainInput = false
        started = true
        startDate = Date()
        elapsedTime = 0
        // Cancel any existing timer
        timerCancellable?.cancel()
        // Create a timer publisher that emits every second on the main run loop
        timerCancellable = Timer.publish(every: 1, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.startDate else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
    }

    /// Resets the game back to its initial state. Stops the timer and clears all UI
    /// state such as highlighted targets and confetti. Also removes any saved
    /// progress from persistent storage.
    public func resetGame() {
        started = false
        showMainInput = false
        showConfetti = false
        dragHoverTargetId = nil
        timerCancellable?.cancel()
        elapsedTime = 0
        startDate = nil
        engine.reset()
        mainInput = Array(repeating: "", count: 6)
        // Remove saved state
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Returns the list of target ids that can accept the given piece. This is
    /// calculated by deferring to the engine. The UI uses this to restrict drop
    /// locations and highlight valid diagonals when dragging.
    public func validTargets(for pieceId: String) -> [String] {
        engine.validTargets(for: pieceId)
    }

    /// Called when the user drops a chip onto a diagonal. Attempts to place the
    /// piece on the target. If the placement fails (due to length mismatch or
    /// conflicts) this method triggers haptic feedback and returns false.
    @discardableResult
    public func handleDrop(pieceId: String, onto targetId: String) -> Bool {
        let success = engine.placePiece(pieceId: pieceId, on: targetId)
        if success {
            // Check if all pieces have been placed to reveal main input
            if engine.state.targets.allSatisfy({ $0.pieceId != nil }) {
                withAnimation {
                    showMainInput = true
                }
            }
            // Persist progress after successful placement
            saveState()
        } else {
            // Provide brief haptic and audio feedback on invalid drop
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        return success
    }

    /// Removes the piece occupying the given target and returns it to the panel. Also
    /// hides the main input if any piece is removed. Persisted state is updated.
    public func removePiece(from targetId: String) {
        guard let _ = engine.removePiece(from: targetId) else { return }
        // When a piece is removed the board is no longer complete so hide the main
        // diagonal input until placement resumes
        withAnimation {
            showMainInput = false
        }
        // Persist progress
        saveState()
    }

    /// Writes the letters from the UI bound main input into the engine. This method
    /// trims whitespace and uppercases each character before updating the engine’s
    /// state. If the puzzle becomes solved after this operation the confetti is
    /// triggered.
    public func commitMainInput() {
        // Normalize input to uppercase single characters
        var letters: [String] = []
        for ch in mainInput {
            if let first = ch.uppercased().first {
                letters.append(String(first))
            } else {
                letters.append("")
            }
        }
        engine.setMainDiagonal(letters)
        saveState()
        // If puzzle solved show confetti and play success haptic/audio
        if engine.state.solved {
            triggerWinEffects()
        }
    }

    /// Undo the most recent board mutation. If successful the main input visibility
    /// and stored letters are updated accordingly and persisted. Returns true on
    /// success.
    @discardableResult
    public func undo() -> Bool {
        let ok = engine.undo()
        if ok {
            // If any target becomes empty hide the main input
            if !engine.state.targets.allSatisfy({ $0.pieceId != nil }) {
                showMainInput = false
            }
            // Update main input from engine
            mainInput = engine.state.mainDiagonal.value
            saveState()
        }
        return ok
    }

    /// Redo the most recently undone board mutation. Mirrors undo in terms of
    /// updating UI state and persistence. Returns true on success.
    @discardableResult
    public func redo() -> Bool {
        let ok = engine.redo()
        if ok {
            // If all pieces placed show main input
            if engine.state.targets.allSatisfy({ $0.pieceId != nil }) {
                showMainInput = true
            }
            mainInput = engine.state.mainDiagonal.value
            saveState()
            if engine.state.solved {
                triggerWinEffects()
            }
        }
        return ok
    }

    /// Called by drop delegates when a drag enters a target’s drop area. Updates the
    /// highlighted target id so the UI can visually indicate the valid destination.
    public func dragEntered(targetId: String) {
        dragHoverTargetId = targetId
    }

    /// Called by drop delegates when the pointer exits a target’s drop area. Clears
    /// the highlight.
    public func dragExited(targetId: String) {
        if dragHoverTargetId == targetId {
            dragHoverTargetId = nil
        }
    }

    /// Convenience accessor exposing the current solved flag from the engine state.
    public var isSolved: Bool {
        engine.state.solved
    }

    /// Returns the elapsed time as a formatted string mm:ss for display in the UI.
    public var elapsedTimeString: String {
        if finished {
            let minutes = Int(finishTime) / 60
            let seconds = Int(finishTime) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Saves the current engine state to UserDefaults for persistence. The state is
    /// encoded as JSON. If encoding fails the save is silently ignored.
    private func saveState() {
        do {
            let data = try JSONEncoder().encode(engine.state)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // ignore errors
        }
    }

    /// Loads the saved engine state from UserDefaults if available. Returns nil
    /// when no saved state exists or decoding fails. If the saved state has a
    /// mismatching set of targets/pieces (because the puzzle configuration changed)
    /// the restore is ignored.
    private static func loadSavedState(for configuration: PuzzleConfiguration) -> GameState? {
        guard let data = UserDefaults.standard.data(forKey: "diagone_state") else { return nil }
        do {
            let state = try JSONDecoder().decode(GameState.self, from: data)
            // Verify that the loaded state has the same number of targets and pieces
            if state.targets.count == configuration.diagonals.count - 1 && state.pieces.count == configuration.pieceLetters.count {
                return state
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Triggers the win effects: confetti burst, success haptic and optionally a
    /// sound. Confetti will automatically hide after a short delay.
    private func triggerWinEffects() {
        finished = true
        finishTime = elapsedTime
        showMainInput = false
        withAnimation {
            showConfetti = true
        }
        // Success haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        // Hide confetti after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.showConfetti = false
        }
    }

    // MARK: - Dragging Hooks
    @MainActor
    public func beginDragging(pieceId: String) {
        draggingPieceId = pieceId
        dragHoverTargetId = nil
    }

    /// Invoked by chips when the drag operation completes, regardless of whether
    /// the drop succeeds. Resets both the dragging piece and the hover target.
    public func endDragging() {
        draggingPieceId = nil
        dragHoverTargetId = nil
    }

    // MARK: - Custom Drag Helpers (manual drag mode)

    /// Called by `ChipView` on every drag gesture change. Converts the provided
    /// global location into board space and determines if the user is hovering
    /// over a valid diagonal. If so the `dragHoverTargetId` is set to the
    /// corresponding target id; otherwise it is cleared. The board frame must
    /// be known (non‑zero) for this method to operate.
    @MainActor
    public func updateDrag(globalLocation: CGPoint) {
        guard let pid = draggingPieceId, boardFrameGlobal != .zero else {
            dragHoverTargetId = nil; return
        }
        // Convert to board-local coords
        let p = CGPoint(x: globalLocation.x - boardFrameGlobal.minX,
                        y: globalLocation.y - boardFrameGlobal.minY)

        let cell = boardFrameGlobal.size.width / 6.0
        let pad  = cell * 0.30 // fuzzy hover
        let valid = Set(engine.validTargets(for: pid))

        var hovered: String? = nil
        for t in engine.state.targets where valid.contains(t.id) {
            let rows = t.cells.map(\.row), cols = t.cells.map(\.col)
            guard let minR = rows.min(), let maxR = rows.max(),
                  let minC = cols.min(), let maxC = cols.max() else { continue }

            let rect = CGRect(x: CGFloat(minC) * cell,
                              y: CGFloat(minR) * cell,
                              width:  CGFloat(maxC - minC + 1) * cell,
                              height: CGFloat(maxR - minR + 1) * cell)
                .insetBy(dx: -pad, dy: -pad)

            if rect.contains(p) { hovered = t.id; break }
        }
        dragHoverTargetId = hovered
    }

    @MainActor
    public func finishDrag() {
        defer { draggingPieceId = nil; dragHoverTargetId = nil }
        guard let pid = draggingPieceId, let tid = dragHoverTargetId else { return }

        let success = engine.placePiece(pieceId: pid, on: tid)
        if success {
            if engine.state.targets.allSatisfy({ $0.pieceId != nil }) {
                withAnimation { showMainInput = true }
            }
            saveState()
        } else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}
