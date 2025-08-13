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
            ScrollView {
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
            }
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
        let lengths = [1, 2, 3, 4, 5]
        let sumDiag = lengths.reduce(0.0) { $0 + sqrt(2.0) * Double($1) }
        // Factor controlling spacing relative to cell size. Adjust for desired
        // padding between chips. 0.3 yields 30% of cell size as spacing.
        let spacingFactor: Double = 0.3
        let denom = sumDiag + spacingFactor * Double(lengths.count - 1)
        return totalWidth / CGFloat(denom)
    }

    @ViewBuilder
    private func chipPane(width: CGFloat) -> some View {
        let cellSize = computeChipCellSize(totalWidth: width * 0.9)

        // group by length
        let groups = Dictionary(grouping: viewModel.engine.state.pieces, by: \.length)

        // pick first/second chip for lengths 1...5 (sorted for stability)
        let row1: [GamePiece] = (1...5).compactMap {
            groups[$0]?.sorted { $0.id < $1.id }.first
        }
        let row2: [GamePiece] = (1...5).compactMap {
            groups[$0]?.sorted { $0.id < $1.id }.dropFirst().first
        }

        VStack(spacing: cellSize * 0.6) {
            HStack(spacing: cellSize * 0.4) {
                ForEach(row1, id: \.id) { piece in
                    ChipView(piece: piece, cellSize: cellSize, hidden: !viewModel.started)
                }
            }
            HStack(spacing: cellSize * 0.4) {
                ForEach(row2, id: \.id) { piece in
                    ChipView(piece: piece, cellSize: cellSize, hidden: !viewModel.started)
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
