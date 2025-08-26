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
//    @Published public var winBounceIndex: Int? = nil
    /// Set of flattened board indices (0..35) currently bouncing. Used for diagonal wave animation.
//    @Published public var winBounceIndices: Set<Int> = []
    @Published public var winWaveTrigger: Int = 0
    private var winWaveTask: Task<Void, Never>?
    

    private var timerCancellable: AnyCancellable?
    private var startDate: Date?
    private let storageKey = "diagone_state"

    // MARK: - Lightweight per-day meta persistence (hub state)
    private struct DailyMeta: Codable {
        var started: Bool
        var finished: Bool
        var elapsedTime: TimeInterval
        var finishTime: TimeInterval
        var lastUpdated: Date
    }

    /// Key used to persist the hub state for today's puzzle date (yyyy-MM-dd, UTC).
    private var metaKey: String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0) // daily boundary stability
        fmt.dateFormat = "yyyy-MM-dd"
        let day = fmt.string(from: Date())
        return "diagone_meta_\(day)"
    }

    private func loadDailyMeta() -> DailyMeta? {
        guard let data = UserDefaults.standard.data(forKey: metaKey) else { return nil }
        return try? JSONDecoder().decode(DailyMeta.self, from: data)
    }

    private func saveDailyMeta(started: Bool? = nil,
                               finished: Bool? = nil,
                               elapsedTime: TimeInterval? = nil,
                               finishTime: TimeInterval? = nil) {
        var current = loadDailyMeta() ?? DailyMeta(started: false, finished: false, elapsedTime: 0, finishTime: 0, lastUpdated: Date())
        if let s = started { current.started = s }
        if let f = finished { current.finished = f }
        if let e = elapsedTime { current.elapsedTime = e }
        if let ft = finishTime { current.finishTime = ft }
        current.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: metaKey)
        }
    }

    public init(engine: GameEngine = GameEngine(puzzleDate: Date())) {
        self.engine = engine

        // Restore lightweight hub state for today's puzzle (by date key)
        let meta = self.loadDailyMeta()
        if let meta = meta {
            self.started = meta.started
            self.finished = meta.finished
            self.elapsedTime = meta.elapsedTime
            self.finishTime = meta.finishTime
        } else {
            // No meta for today -> ensure we start fresh
            self.started = false
            self.finished = false
            self.elapsedTime = 0
            self.finishTime = 0
        }

        // Only restore board state if today's meta indicates we started today.
        if meta?.started == true, let restored = Self.loadSavedState(for: engine.configuration) {
            engine.restore(restored)
            // Determine if the main input should be visible based on number of placed pieces
            let allPlaced = engine.state.targets.allSatisfy { $0.pieceId != nil }
            self.showMainInput = allPlaced
            self.mainInput = engine.state.mainDiagonal.value
        } else {
            // Fresh day -> clear any stale state from prior day
            engine.reset()
            self.showMainInput = false
            self.mainInput = Array(repeating: "", count: 6)
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
        // Persist meta: mark started, reset finished, elapsed/finish time
        saveDailyMeta(started: true, finished: false, elapsedTime: 0, finishTime: 0)
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
                self.saveDailyMeta(elapsedTime: self.elapsedTime)
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
        guard !finished else { return false }
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
        guard !finished else { return }
        guard let removedId = engine.removePiece(from: targetId) else { return }
        // Piece is coming back to the pane; restore interactivity/opacity there.
        fadingPanePieceIds.remove(removedId)
        // When a piece is removed the board is no longer complete so hide the main diagonal input until placement resumes
        withAnimation(.easeInOut(duration: 0.1)) {
            clearMainDiagonal()
        }
        // Persist progress
        saveState()
        // If user is making changes, ensure we are not marked finished
        if finished {
            finished = false
            saveDailyMeta(finished: false)
        }
    }

    /// Writes the letters from the UI bound main input into the engine. This method
    /// trims whitespace and uppercases each character before updating the engine’s
    /// state. If the puzzle becomes solved after this operation the confetti is
    /// triggered.
    public func commitMainInput() {
        guard !finished else { return }
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
        saveDailyMeta(elapsedTime: elapsedTime)
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
        // Ensure any keyboard is dismissed on win
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
        // Persist meta so the hub shows "completed" on relaunch
        saveDailyMeta(started: true, finished: true, elapsedTime: elapsedTime, finishTime: finishTime)
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

        let totalSteps = 11
        let perStep: Duration = .milliseconds(70) // staging gap between diagonals
        let tail: Duration = .milliseconds(420)   // time for last bounces to settle

        winWaveTask = Task(priority: .userInitiated) { @MainActor in
            // Fire one model change; views do the staggering
            self.winWaveTrigger &+= 1

            let clock = ContinuousClock()
            try? await clock.sleep(for: perStep * (totalSteps - 1) + tail)

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.startConfettiSequence()
        }
    }

    deinit {
        timerCancellable?.cancel()
        winWaveTask?.cancel()
    }


    private func startConfettiSequence() {
        // Present confetti (no sheets)
        withAnimation { self.showConfetti = true }

        // Second quick burst for a more organic feel
        let firstPause: TimeInterval = 1.1
        DispatchQueue.main.asyncAfter(deadline: .now() + firstPause) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.08)) { self.showConfetti = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                withAnimation { self?.showConfetti = true }
            }
        }

        // End the confetti after the combined sequence
        let totalDuration: TimeInterval = 2.8
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            withAnimation { self?.showConfetti = false }
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
        guard !finished else { return }
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
        guard !finished, let pid = draggingPieceId, boardFrameGlobal != .zero else {
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
        guard !finished else { return }
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
        guard !finished else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        removePiece(from: targetId)
        
    }
    /// Pauses the in-progress game timer and persists current elapsed time.
    public func pause() {
        guard started, !finished else { return }
        timerCancellable?.cancel()
        timerCancellable = nil
        startDate = nil
        saveDailyMeta(started: true, finished: false, elapsedTime: elapsedTime)
    }
    
    /// Resumes the in-progress game timer from the current `elapsedTime`.
    @MainActor
    public func resume() {
        guard started, !finished else { return }
        // Avoid duplicating timers
        if timerCancellable != nil { return }
        let start = Date().addingTimeInterval(-elapsedTime)
        self.startDate = start
        let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        self.timerCancellable = ticker.sink { [weak self] _ in
            guard let self = self, let s = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(s)
            self.saveDailyMeta(started: true, finished: false, elapsedTime: self.elapsedTime)
        }
    }
}
