import SwiftUI

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Root view composing the game interface. Contains a header with the title,
/// timer and control buttons, the board itself, the chip selection pane and
/// optionally the main diagonal input. Relies heavily on `GameViewModel` to
/// drive state and actions.
struct DiagoneContentView: View {
    @StateObject var viewModel: GameViewModel
    @Environment(\.scenePhase) private var scenePhase
    let onBackToHome: () -> Void

    @MainActor
    init(viewModel: GameViewModel, onBackToHome: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onBackToHome = onBackToHome
    }
    /// Local state tracking which row is currently highlighted during the win
    /// animation. This is advanced sequentially when the puzzle is solved to
    /// produce a celebratory sweep across the board.
    @State private var highlightedRow: Int? = nil
    /// Timer used to coordinate row highlighting after win. Cancelled when
    /// animation completes.
    @State private var winHighlightTimer: Timer? = nil

    @State private var showHub: Bool = true


    private enum HubMode { case notStarted, inProgress, completed }
    private var hubMode: HubMode {
        if viewModel.isSolved {
            return .completed
        } else if viewModel.started {
            return .inProgress
        } else {
            return .notStarted
        }
    }

    var body: some View {
        Group {
            if showHub {
                startHub
            } else {
                GeometryReader { geo in
                    let width = geo.size.width
                    VStack(spacing: 0) {
                        // Header: title, timer and control buttons
                        header

                        VStack(spacing: 20) {
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
            }
        }
        .environmentObject(viewModel)
        .onAppear {
            if !viewModel.started {
                // Coming from loading screen - start the game and go directly to game
                viewModel.startGame()
                showHub = false
            } else {
                // Returning to paused or completed game - show hub
                showHub = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                if viewModel.started && !viewModel.isSolved {
                    viewModel.pause()
                    showHub = true
                }
            }
        }
        .onChange(of: viewModel.isSolved, initial: false) { _, solved in
            if solved {
                UIApplication.shared.endEditing()
            }
        }
        .onChange(of: showHub) { _, isShowing in
            if !isShowing {
                // Extra safety: ensure keyboard is dismissed when exiting the hub
                UIApplication.shared.endEditing()
                // In case any view auto-focuses on appear, dismiss again on next runloop
                DispatchQueue.main.async {
                    UIApplication.shared.endEditing()
                }
                if viewModel.finished { viewModel.showMainInput = false }
            }
        }
        .onChange(of: viewModel.finished) { _, didFinish in
            if didFinish {
                // Ensure keyboard is dismissed immediately and after any layout updates
                UIApplication.shared.endEditing()
                viewModel.showMainInput = false
                DispatchQueue.main.async { UIApplication.shared.endEditing() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Closing/minimizing the app while editing: force dismiss
            UIApplication.shared.endEditing()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Belt-and-suspenders: also dismiss on background
            UIApplication.shared.endEditing()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // On resume, don't allow any text field to reclaim focus if the puzzle is finished
            if viewModel.finished {
                UIApplication.shared.endEditing()
                DispatchQueue.main.async { UIApplication.shared.endEditing() }
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                UIApplication.shared.endEditing()
                viewModel.pause()
                showHub = true
            } label: {
                Label("Back", systemImage: "chevron.backward")
                    .font(.headline)
            }

            Spacer()

            Text("Diagone")
                .font(.headline)

            Spacer()

            if viewModel.started && !viewModel.isSolved {
                // In-progress: show timer + pause
                HStack(spacing: 8) {
                    Text(viewModel.elapsedTimeString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    Button {
                        viewModel.pause()
                        showHub = true
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 75, alignment: .trailing)
            } else if viewModel.started && viewModel.isSolved {
                // Solved: show elapsed only
                Text(viewModel.elapsedTimeString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(width: 75, alignment: .trailing)
            } else {
                Color.clear.frame(width: 75)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.boardCell.opacity(0.1))
    }


    // MARK: - Start / Resume / Completed Hub
    private var startHub: some View {
        VStack(spacing: 0) {

            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.mainDiagonal)

                Text("Diagone")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Drag and drop diagonals to spell six horizontal words")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
            }

            Spacer()

            // Bottom content - state-specific
            VStack(spacing: 16) {
                switch hubMode {
                case .notStarted:
                    Button(action: {
                        UIApplication.shared.endEditing()
                        viewModel.startGame()
                        showHub = false
                    }) {
                        Text("Play")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.mainDiagonal)
                            .cornerRadius(12)
                    }

                case .inProgress:
                    Text("You're in the middle of today's puzzle.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(viewModel.elapsedTimeString)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()

                    Button(action: {
                        UIApplication.shared.endEditing()
                        viewModel.resume()
                        showHub = false
                    }) {
                        Text("Resume")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.mainDiagonal)
                            .cornerRadius(12)
                    }

                    Button(action: onBackToHome) {
                        Text("Back to Home")
                            .font(.headline)
                            .foregroundColor(.mainDiagonal)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.mainDiagonal, lineWidth: 2)
                            )
                    }

                case .completed:
                    Text("Great job!")
                        .font(.title3.weight(.semibold))

                    Text("Time: \(String(format: "%02d:%02d", Int(viewModel.finishTime) / 60, Int(viewModel.finishTime) % 60))")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()

                    Text("Check back tomorrow for a new puzzle!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: {
                        UIApplication.shared.endEditing()
                        if viewModel.finished { viewModel.showMainInput = false }
                        DispatchQueue.main.async {
                            UIApplication.shared.endEditing()
                        }
                        showHub = false
                        viewModel.runWinSequence()
                    }) {
                        Text("View Today's Puzzle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.mainDiagonal)
                            .cornerRadius(12)
                    }

                    Button(action: onBackToHome) {
                        Text("Back to Home")
                            .font(.headline)
                            .foregroundColor(.mainDiagonal)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.mainDiagonal, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.boardCell.opacity(0.2).ignoresSafeArea())
    }

    // MARK: - Chip Pane

    /// Constant gap between chips in the pane
    private var chipGap: CGFloat { 4 }

    /// Fixed horizontal margin for chip pane (equal on both sides)
    private var chipPaneMargin: CGFloat { 20 }

    /// Calculates the span (width/height) for a chip of given length
    private func chipSpan(length: Int, cellSize: CGFloat) -> CGFloat {
        let tileSize = cellSize * 0.85
        let step = tileSize * 0.72
        return step * CGFloat(length - 1) + tileSize
    }

    /// Calculates the vertical offset to align visual centers of diagonal chips.
    /// The visual center of a diagonal is at the middle tile (or midpoint between middle tiles).
    /// For length n, visual center Y = (n-1)/2 * step + tileSize/2
    /// To align all to the 5-tile center, offset = (5 - n) * step / 2
    private func chipVerticalOffset(length: Int, cellSize: CGFloat) -> CGFloat {
        let tileSize = cellSize * 0.85
        let step = tileSize * 0.72
        return CGFloat(5 - length) * step / 2
    }

    /// Calculates cell size for chips based on available width.
    /// Uses proportional spacing where each chip takes space based on its actual size.
    private func computeChipCellSize(totalWidth: CGFloat) -> CGFloat {
        // Sum of span factors for lengths 1-5:
        // span(n) = tileSize * (1 + 0.72 * (n-1)) where tileSize = cellSize * 0.85
        // Total factor = 0.85 * (1 + 1.72 + 2.44 + 3.16 + 3.88) = 0.85 * 12.2 ≈ 10.37
        let tileFactor: CGFloat = 0.85
        let stepFactor: CGFloat = 0.72
        var totalSpanFactor: CGFloat = 0
        for length in 1...5 {
            totalSpanFactor += tileFactor * (1 + stepFactor * CGFloat(length - 1))
        }
        // Available width = total width minus equal margins on both sides minus gaps between chips
        let availableWidth = totalWidth - (2 * chipPaneMargin) - (4 * chipGap)
        return availableWidth / totalSpanFactor
    }

    @ViewBuilder
    private func chipPane(width: CGFloat) -> some View {
        let cellSize = computeChipCellSize(totalWidth: width)

        // Max height is the 5-letter chip span
        let maxChipHeight = chipSpan(length: 5, cellSize: cellSize)

        // Prepare rows: for each length 1...5, take first chip and second chip
        let groups = Dictionary(grouping: viewModel.engine.state.pieces, by: \.length)
        let sorted = { (xs: [GamePiece]) in
            xs.sorted { lhs, rhs in
                let li = Int(lhs.id.drop(while: { !$0.isNumber })) ?? 0
                let ri = Int(rhs.id.drop(while: { !$0.isNumber })) ?? 0
                return li < ri
            }
        }
        let row1Opt: [GamePiece?] = (1...5).map { groups[$0].map(sorted)?.first }
        let row2Opt: [GamePiece?] = (1...5).map { groups[$0].map(sorted)?.dropFirst().first }

        VStack(spacing: 8) {
            // Row 1: chips aligned by visual center of diagonal
            HStack(alignment: .top, spacing: chipGap) {
                ForEach(0..<5, id: \.self) { i in
                    let length = i + 1
                    let span = chipSpan(length: length, cellSize: cellSize)
                    let vOffset = chipVerticalOffset(length: length, cellSize: cellSize)
                    if let p = row1Opt[i] {
                        ChipView(piece: p, cellSize: cellSize, hidden: !viewModel.started)
                            .frame(width: span, height: span, alignment: .topLeading)
                            .padding(.top, vOffset)
                            .frame(height: maxChipHeight, alignment: .top)
                    } else {
                        Color.clear
                            .frame(width: span, height: maxChipHeight)
                    }
                }
            }
            // Row 2: same layout
            HStack(alignment: .top, spacing: chipGap) {
                ForEach(0..<5, id: \.self) { i in
                    let length = i + 1
                    let span = chipSpan(length: length, cellSize: cellSize)
                    let vOffset = chipVerticalOffset(length: length, cellSize: cellSize)
                    if let p = row2Opt[i] {
                        ChipView(piece: p, cellSize: cellSize, hidden: !viewModel.started)
                            .frame(width: span, height: span, alignment: .topLeading)
                            .padding(.top, vOffset)
                            .frame(height: maxChipHeight, alignment: .top)
                    } else {
                        Color.clear
                            .frame(width: span, height: maxChipHeight)
                    }
                }
            }
        }
        .padding(.horizontal, chipPaneMargin)
    }


    // MARK: - Row Highlight Animation
    /// Starts the win highlight animation. Sequentially highlights each row of the
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
                // After the win animation completes, show the completed hub
                UIApplication.shared.endEditing()
                showHub = true
            }
        }
    }
}
