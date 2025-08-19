import Foundation
import SwiftUI
import Combine
import UIKit

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
    /// Incorrect-state feedback flags (NYT-style, subtle)
    @Published public var showIncorrectFeedback: Bool = false
    /// Triggers a gentle board shake when incremented
    @Published public var shakeTrigger: Int = 0
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

    /// Piece ids currently fading out from the selection pane after a successful placement.
    @Published public var fadingPanePieceIds: Set<String> = []

    /// The global screen coordinates of the current drag location. Updated by
    /// the chip's `DragGesture` on every movement. The board uses this to
    /// calculate which diagonal the user is hovering over.
    @Published public var dragGlobalLocation: CGPoint? = nil

    /// The frame of the board in global coordinates. This is set by the
    /// `BoardView` via a `GeometryReader` so that drag positions can be
    /// converted into board space when determining hover state. It will be
    /// `.zero` until the board appears on screen.
    @Published public var boardFrameGlobal: CGRect = .zero
    
    // Win sequence state
    @Published public var winBounceIndex: Int? = nil
    /// Set of flattened board indices (0..35) currently bouncing. Used for diagonal wave animation.
    @Published public var winBounceIndices: Set<Int> = []
    @Published public var showWinSheet: Bool = false
    private var winWaveTask: Task<Void, Never>?

    private var timerCancellable: AnyCancellable?
    private var startDate: Date?
    private let storageKey = "diagone_state"

    public init(engine: GameEngine = GameEngine(puzzleDate: Date())) {
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
        engine.reset()
        mainInput = Array(repeating: "", count: 6)
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
        let (success, replacedId) = engine.placeOrReplace(pieceId: pieceId, on: targetId)
        if success {
            // Newly placed chip should appear inactive in the pane
            fadingPanePieceIds.insert(pieceId)
            // If a chip was replaced, re‑enable it in the pane
            if let rid = replacedId { fadingPanePieceIds.remove(rid) }

            if engine.state.targets.allSatisfy({ $0.pieceId != nil }) {
                withAnimation { showMainInput = true }
            }
            saveState()
            maybeHandleCompletionState()
        } else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        return success
    }

    /// Removes the piece occupying the given target and returns it to the panel. Also
    /// hides the main input if any piece is removed. Persisted state is updated.
    public func removePiece(from targetId: String) {
        guard let removedId = engine.removePiece(from: targetId) else { return }
        // Piece is coming back to the pane; restore interactivity/opacity there.
        fadingPanePieceIds.remove(removedId)
        // When a piece is removed the board is no longer complete so hide the main diagonal input until placement resumes
        withAnimation(.easeInOut(duration: 0.1)) {
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
        maybeHandleCompletionState()
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
    
    private func triggerWinEffects() {
        finished = true
        finishTime = elapsedTime
        timerCancellable?.cancel()
        timerCancellable = nil
        startDate = nil
        showMainInput = false

        // Don't show confetti until the wave completes
        winWaveTask?.cancel()
        showConfetti = false
        runWinSequence()
    }

    private func runWinSequence() {
        winWaveTask?.cancel()

        let totalSteps = 11 // 0...10 anti-diagonals on a 6x6
        // For wave overlap: stepInterval < bounce duration (response)
        let stepInterval: TimeInterval = 0.12 // Slower: doubled from 0.06
        let bounceResponse: Double = 0.7      // Slower: doubled from 0.35
        let bounceDamping: Double = 0.55
        let bounceBlend: Double = 0.08
        let clearDelay: TimeInterval = 0.44   // Slower: doubled from 0.22 for consistent overlap

        winWaveTask = Task { @MainActor in
            for step in 0..<totalSteps {
                // Start bounce for this anti-diagonal (longer spring for overlap)
                withAnimation(.spring(response: bounceResponse, dampingFraction: bounceDamping, blendDuration: bounceBlend)) {
                    self.winBounceIndex = step
                }
                // Schedule clearing winBounceIndex with a delay, so the next step's bounce overlaps
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(clearDelay * 1_000_000_000))
                    // Only clear if not overwritten by a new step
                    if self.winBounceIndex == step {
                        withAnimation(.easeOut(duration: 0.08)) {
                            self.winBounceIndex = nil
                        }
                    }
                }
                // Wait before starting next step (overlap: stepInterval < bounce duration)
                if step < totalSteps - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))
                }
            }
            // After all 11 steps, fire confetti then results sheet
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self.fireConfettiThenSheet()
        }
    }

    deinit {
        timerCancellable?.cancel()
        winWaveTask?.cancel()
    }

    private func fireConfettiThenSheet() {
        // 2) Confetti burst (short and sweet)
        withAnimation { showConfetti = true }
        let confettiDuration: TimeInterval = 2
        DispatchQueue.main.asyncAfter(deadline: .now() + confettiDuration) { [weak self] in
            guard let self = self else { return }
            withAnimation { self.showConfetti = false }
            // 3) Results sheet
            self.showWinSheet = true
        }
    }

    /// Triggers a subtle incorrect feedback: gentle haptic + quick board shake + brief toast (driven by showIncorrectFeedback in the view layer)
    private func triggerIncorrectFeedback() {
        // Haptic: a soft warning nudge
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        // Shake: increment trigger to animate a small horizontal shake
        withAnimation(.easeIn(duration: 0.12)) {
            shakeTrigger += 1
            showIncorrectFeedback = true
        }
        // Auto-hide any visual overlays driven by showIncorrectFeedback after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                self?.showIncorrectFeedback = false
            }
        }
        clearMainDiagonal()
    }

    /// Clears the main diagonal both in the engine state and the bound input, so new typing doesn't instantly retrigger feedback.
    private func clearMainDiagonal() {
        let count = engine.state.mainDiagonal.cells.count
        let empty = Array(repeating: "", count: count)
        // Keep the UI text fields in sync so the board is no longer considered "full".
        mainInput = empty
        // Use the engine API to clear the diagonal (handles undo/redo and recomputeBoard).
        engine.setMainDiagonal(empty)
        saveState()
    }

    /// Call after any state change that might complete the puzzle: if solved, celebrate; if full but incorrect, nudge.
    private func maybeHandleCompletionState() {
        let allPlaced = engine.state.targets.allSatisfy { $0.pieceId != nil }
        let mainFilled = engine.state.mainDiagonal.value.allSatisfy { !$0.isEmpty }
        guard allPlaced && mainFilled else { return }
        if engine.state.solved {
            triggerWinEffects()
        } else {
            triggerIncorrectFeedback()
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

        // Convert to board-local coords (points)
        let p = CGPoint(x: globalLocation.x - boardFrameGlobal.minX,
                        y: globalLocation.y - boardFrameGlobal.minY)

        // Board metrics
        let side = min(boardFrameGlobal.size.width, boardFrameGlobal.size.height)
        let cell = side / 6.0

        // Only consider targets that match the dragged piece length
        let valid = Set(engine.validTargets(for: pid))

        // Helper: distance from point to the line segment defined by the target's first/last cell centers
        func distanceToDiagonal(_ t: GameTarget, point: CGPoint) -> (distance: CGFloat, length: Int) {
            guard let first = t.cells.first, let last = t.cells.last else { return (.greatestFiniteMagnitude, t.length) }
            // Centers of start and end cells in board-local space
            let a = CGPoint(x: (CGFloat(first.col) + 0.5) * cell,
                            y: (CGFloat(first.row) + 0.5) * cell)
            let b = CGPoint(x: (CGFloat(last.col) + 0.5) * cell,
                            y: (CGFloat(last.row) + 0.5) * cell)
            let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let ap = CGPoint(x: point.x - a.x, y: point.y - a.y)
            let abLen2 = max(ab.x*ab.x + ab.y*ab.y, 0.0001)
            var tParam = (ap.x*ab.x + ap.y*ab.y) / abLen2
            tParam = min(max(tParam, 0.0), 1.0) // clamp to segment
            let proj = CGPoint(x: a.x + ab.x * tParam, y: a.y + ab.y * tParam)
            let dx = point.x - proj.x
            let dy = point.y - proj.y
            let d = sqrt(dx*dx + dy*dy)
            return (d, t.length)
        }

        // Choose the closest valid diagonal under a length-aware radius threshold ("sausage" test)
        var bestId: String? = nil
        var bestDist: CGFloat = .greatestFiniteMagnitude

        for t in engine.state.targets where valid.contains(t.id) {
            let (dist, len) = distanceToDiagonal(t, point: p)
            // Length-aware radius: slightly looser for longer diagonals.
            // len=1 => ~0.48*cell, len=5 => ~0.408*cell
            let radius = cell * (0.48 - 0.018 * CGFloat(len - 1))
            // Also reject points that are far beyond the segment ends by adding a mild bounding box check.
            let rows = t.cells.map(\.row)
            let cols = t.cells.map(\.col)
            if let minR = rows.min(), let maxR = rows.max(), let minC = cols.min(), let maxC = cols.max() {
                let box = CGRect(x: CGFloat(minC) * cell - cell * 0.25,
                                 y: CGFloat(minR) * cell - cell * 0.25,
                                 width:  CGFloat(maxC - minC + 1) * cell + cell * 0.5,
                                 height: CGFloat(maxR - minR + 1) * cell + cell * 0.5)
                guard box.contains(p) else { continue }
            }
            guard dist <= radius else { continue }
            if dist < bestDist { bestDist = dist; bestId = t.id }
        }

        dragHoverTargetId = bestId
    }

    @MainActor
    public func finishDrag() {
        defer { draggingPieceId = nil; dragHoverTargetId = nil }
        guard let pid = draggingPieceId, let tid = dragHoverTargetId else { return }

        let (success, replacedId) = engine.placeOrReplace(pieceId: pid, on: tid)
        if success {
            // Newly placed chip should appear inactive in the pane
            fadingPanePieceIds.insert(pid)
            // The replaced chip (if any) returns to the pane; restore its interactivity
            if let rid = replacedId { fadingPanePieceIds.remove(rid) }

            if engine.state.targets.allSatisfy({ $0.pieceId != nil }) {
                withAnimation { showMainInput = true }
            }
            saveState()
            maybeHandleCompletionState()
        } else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }

    /// Convenience for views to check whether a pane chip should be faded/disabled.
    public func isPaneChipInactive(_ pieceId: String) -> Bool {
        let placed = engine.state.pieces.first(where: { $0.id == pieceId })?.placedOn != nil
        return placed || fadingPanePieceIds.contains(pieceId)
    }
    
    // MARK: - Taps
    public func handleTap(on targetId: String) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        removePiece(from: targetId)
    }
}
