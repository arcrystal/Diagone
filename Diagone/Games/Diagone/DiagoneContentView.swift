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
        VStack(spacing: 24) {
            HStack {
                Button(action: onBackToHome) {
                    Label("Back", systemImage: "chevron.backward")
                        .font(.headline)
                        .padding()
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 20)

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
                .padding(.horizontal, 40)

            Spacer()

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
                .padding(.horizontal, 40)
                .padding(.bottom, 40)

            case .inProgress:
                VStack(spacing: 16) {
                    Text("You're in the middle of today's puzzle.")
                        .font(.title3.weight(.semibold))
                    Text("Elapsed: \(viewModel.elapsedTimeString)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)

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
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)

            case .completed:
                VStack(spacing: 12) {
                    Text("Great job!")
                        .font(.title3.weight(.semibold))
                    Text("Time: \(String(format: "%02d:%02d", Int(viewModel.finishTime) / 60, Int(viewModel.finishTime) % 60))")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("Check back tomorrow for a new puzzle!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        UIApplication.shared.endEditing()
                        if viewModel.finished { viewModel.showMainInput = false }
                        // Ensure no auto-focus steals first responder as the board reappears
                        DispatchQueue.main.async {
                            UIApplication.shared.endEditing()
                        }
                        showHub = false // return to board
                        viewModel.runWinSequence()
                    } label: {
                        Text("View Today's Puzzle")
                            .font(.headline)
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(Capsule().fill(Color.primary))
                            .foregroundStyle(Color(UIColor.systemBackground))
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .background(Color.boardCell.opacity(0.2).ignoresSafeArea())
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
        let sorted = { (xs: [GamePiece]) in
            xs.sorted { lhs, rhs in
                let li = Int(lhs.id.drop(while: { !$0.isNumber })) ?? 0
                let ri = Int(rhs.id.drop(while: { !$0.isNumber })) ?? 0
                return li < ri
            }
        }
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
