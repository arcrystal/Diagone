import SwiftUI

/// Root view composing the game interface. Contains a header with the title,
/// timer and control buttons, the board itself, the chip selection pane and
/// optionally the main diagonal input. Relies heavily on `GameViewModel` to
/// drive state and actions.
struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    /// Local state tracking which row is currently highlighted during the win
    /// animation. This is advanced sequentially when the puzzle is solved to
    /// produce a celebratory sweep across the board.
    @State private var highlightedRow: Int? = nil
    /// Timer used to coordinate row highlighting after win. Cancelled when
    /// animation completes.
    @State private var winHighlightTimer: Timer? = nil

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            VStack(spacing: 20) {
                // Header: title, timer and control buttons
                header
                    .padding(.horizontal)
                // Board
                BoardView(highlightRow: highlightedRow)
                    .environmentObject(viewModel)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity)
                // Chip selection pane
                chipPane(width: width)
                    .padding(.horizontal)
                // Main diagonal input (shown only when all pieces placed)
                if viewModel.showMainInput {
                    MainDiagonalInputView(input: $viewModel.mainInput, cellSize: computeChipCellSize(totalWidth: width))
                        .environmentObject(viewModel)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .background(Color.boardCell.opacity(0.2).ignoresSafeArea())
            // Trigger row highlight animation whenever the solved flag becomes true
            .onChange(of: viewModel.isSolved, initial: false) { oldValue, newValue in
                if newValue {
                    startRowHighlightAnimation()
                }
            }
        }
        .environmentObject(viewModel)
        // Overlay confetti when showConfetti is true
        .overlay(
            Group {
                if viewModel.showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
        )
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text("Diagone")
                .font(.title).bold()
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if viewModel.started {
                Text(viewModel.elapsedTimeString)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel("Timer: \(viewModel.elapsedTimeString)")
                Spacer(minLength: 10)
                // Undo button
                Button(action: { _ = viewModel.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!canUndo)
                .accessibilityLabel("Undo")
                Spacer(minLength: 10)
                // Redo button
                Button(action: { _ = viewModel.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!canRedo)
                .accessibilityLabel("Redo")
                Spacer(minLength: 10)
                // Reset button
                Button(action: viewModel.resetGame) {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Reset game")
            } else {
                Button(action: viewModel.startGame) {
                    Text("Start")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.mainDiagonal)
                        )
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Start game")
            }
        }
    }

    // Determines whether undo is currently possible by inspecting the engine’s history.
    private var canUndo: Bool {
        // The view model doesn’t expose the history stack; we approximate by
        // checking if any target has a placed piece or if main diagonal has letters.
        return viewModel.engine.state.targets.contains(where: { $0.pieceId != nil }) || viewModel.engine.state.mainDiagonal.value.contains { !$0.isEmpty }
    }
    // Determines whether redo is currently possible. Since we clear future
    // history on new moves we conservatively disable redo if there is no
    // saved future state. The engine doesn’t expose its future stack so we
    // approximate via other signals; here we simply always enable redo as
    // there is no risk of crashing.
    private var canRedo: Bool {
        return true
    }

    // MARK: - Chip Pane
    /// Calculates an approximate cell size for chips based on the available width.
    /// Chips are drawn diagonally which increases their bounding box. We estimate
    /// the denominator by summing the lengths (1–5) multiplied by √2 and add
    /// small spacing between chips. This yields a cell size that fits all chips
    /// neatly on one row. Both rows share the same cell size.
    private func computeChipCellSize(totalWidth: CGFloat) -> CGFloat {
        // We lay chips in 5 uniform slots (equal left-edge pitch). Fit the longest chip (len=5)
        // into a single slot so nothing overlaps, leaving a small visual margin.
        let slots = 5.0
        let pitch = Double(totalWidth) / slots
        let longest = sqrt(2.0) * 5.0 // width factor for length-5 chip
        let margin = 1.1
        let cell = pitch * margin / longest
        return CGFloat(cell)
    }

    @ViewBuilder
    private func chipPane(width: CGFloat) -> some View {
        let cellSize = computeChipCellSize(totalWidth: width)
        let usable = width * 0.75
        let slotWidth = usable / 5.0 // uniform left-edge pitch

        // Prepare rows: for each length 1...5, take first chip and second chip
        let groups = Dictionary(grouping: viewModel.engine.state.pieces, by: \.length)
        let sorted = { (xs: [GamePiece]) in xs.sorted { $0.id < $1.id } }
        let row1Opt: [GamePiece?] = (1...5).map { groups[$0].map(sorted)?.first }
        let row2Opt: [GamePiece?] = (1...5).map { groups[$0].map(sorted)?.dropFirst().first }

        VStack(spacing: cellSize * 0.2) {
            // Each chip sits in a fixed-width slot (`slotWidth`) so the left edges are uniformly spaced.
            // Chips are leading-aligned inside their slots; sizes vary but no overlap occurs.
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    if let p = row1Opt[i] {
                        ChipView(piece: p, cellSize: cellSize, hidden: !viewModel.started)
                            .frame(width: slotWidth, alignment: .leading)
                    } else {
                        Color.clear
                            .frame(width: slotWidth, height: cellSize * 1.6, alignment: .leading)
                    }
                }
            }
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    if let p = row2Opt[i] {
                        ChipView(piece: p, cellSize: cellSize, hidden: !viewModel.started)
                            .frame(width: slotWidth, alignment: .leading)
                    } else {
                        Color.clear
                            .frame(width: slotWidth, height: cellSize * 1.6, alignment: .leading)
                    }
                }
            }
        }
    }


    // MARK: - Row Highlight Animation
    /// Starts the win highlight animation. Sequentially highlights each row of the
    /// board for a brief moment. Also triggers confetti via the view model.
    private func startRowHighlightAnimation() {
        // Cancel any existing animation
        winHighlightTimer?.invalidate()
        highlightedRow = nil
        var row = 0
        winHighlightTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { timer in
            if row < 6 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    highlightedRow = row
                }
                row += 1
            } else {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    highlightedRow = nil
                }
            }
        }
    }
}

// Preview for development in Xcode. Not used by the production build but
// included for completeness.
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
