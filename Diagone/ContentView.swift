import SwiftUI
import UniformTypeIdentifiers

/// The primary view composing the game interface. This struct wires
/// together the game state with the board, panel of chips and input
/// controls. It coordinates selection of pieces, placement on
/// diagonals, main diagonal entry and displays transient messages.
struct ContentView: View {
    // The shared game state powering the UI
    @StateObject private var game = GameState()
    // The id of the currently selected piece, if any
    @State private var selectedPieceId: UUID? = nil
    // When `true` drag and drop mode is active; otherwise tap‑to‑place
    @State private var useDragMode: Bool = false
    // Tracks which main input cell is focused for keyboard entry
    @FocusState private var focusedField: Int?
    // Controls presentation of the settings sheet
    @State private var showingSettings: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Diagone")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .padding(.top, 20)

            // Settings button aligned to the right
            HStack {
                Spacer()
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .regular))
                }
                .padding(.trailing, 16)
                .accessibilityLabel("Settings")
            }

            // Game board
            boardView
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal)

            // Panel of draggable pieces
            panelView
                .padding(.horizontal)

            // Main diagonal entry area
            if game.showMainInput {
                mainInputView
                    .padding(.horizontal)
            }

            // End game state
            if game.isGameWon {
                Text("Congratulations! You solved the puzzle!")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding(.top, 8)
            }

            // Error messages
            if let message = game.message {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom)
        .background(Color(UIColor.systemBackground))
        .sheet(isPresented: $showingSettings) {
            SettingsView(useDragMode: $useDragMode)
        }
    }

    /// Builds the board of 6×6 cells. Each cell reacts to taps for
    /// placement or removal. Highlighting is computed based on the
    /// currently selected piece.
    private var boardView: some View {
        GeometryReader { geo in
            VStack(spacing: 2) {
                ForEach(0..<6, id: \ .self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<6, id: \ .self) { col in
                            let coord = CellCoordinate(row: row, col: col)
                            CellView(
                                cell: coord,
                                letter: game.board[row][col] ?? "",
                                isMain: row == col,
                                isHighlighted: isHighlighted(cell: coord),
                                onTap: {
                                    handleCellTap(cell: coord)
                                }
                            )
                            // Support drag and drop when enabled. The drop
                            // handler interprets the string coming from
                            // NSItemProvider as a UUID and attempts to place
                            // the piece on the tapped diagonal. If the
                            // diagonal length matches the piece length the
                            // operation will succeed. Otherwise it will be
                            // ignored.
                            .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                                if useDragMode {
                                    return handleDrop(providers: providers, at: coord)
                                }
                                return false
                            }
                        }
                    }
                }
            }
        }
    }

    /// Determines whether a cell should be highlighted based on the
    /// currently selected piece. A cell is highlighted if it lies on
    /// either diagonal whose length equals the selected piece length.
    private func isHighlighted(cell: CellCoordinate) -> Bool {
        guard let selectedId = selectedPieceId else { return false }
        guard let piece = game.pieces.first(where: { $0.id == selectedId }) else { return false }
        guard let diagId = game.cellToTarget[cell] ?? nil else { return false }
        guard let diag = game.targets.first(where: { $0.id == diagId }) else { return false }
        return diag.length == piece.length
    }

    /// Handles taps on individual cells. Behaviour depends on whether
    /// a piece is selected and whether the cell is currently occupied.
    private func handleCellTap(cell: CellCoordinate) {
        // First check if a piece is already occupying this cell – if so
        // remove the piece that owns the entire diagonal.
        if let diagId = game.cellToTarget[cell] ?? nil,
           let diag = game.targets.first(where: { $0.id == diagId }),
           diag.pieceId != nil {
            // Remove the existing piece
            game.removePiece(targetId: diagId)
            // After removing, deselect any selected piece to avoid
            // accidental placement on the same tap
            selectedPieceId = nil
            return
        }
        // If a piece is selected and the tap is on a highlighted diagonal
        if let selectedId = selectedPieceId {
            if let diagId = game.cellToTarget[cell] ?? nil,
               let diag = game.targets.first(where: { $0.id == diagId }),
               diag.length == game.pieces.first(where: { $0.id == selectedId })?.length {
                game.placePiece(pieceId: selectedId, on: diagId)
                selectedPieceId = nil
            }
        }
    }

    /// Attempts to handle a drag‑and‑drop operation. Decodes the first
    /// provider as a UUID string and asks the game state to place the
    /// piece on the diagonal corresponding to the drop location. If
    /// decoding fails or the placement is invalid the drop is rejected.
    @discardableResult
    private func handleDrop(providers: [NSItemProvider], at cell: CellCoordinate) -> Bool {
        guard let provider = providers.first else { return false }
        var handled = false
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
            if let data = item as? Data,
               let idString = String(data: data, encoding: .utf8),
               let pieceId = UUID(uuidString: idString),
               let diagId = game.cellToTarget[cell] ?? nil,
               let diag = game.targets.first(where: { $0.id == diagId }),
               diag.length == game.pieces.first(where: { $0.id == pieceId })?.length {
                DispatchQueue.main.async {
                    game.placePiece(pieceId: pieceId, on: diagId)
                }
                handled = true
            }
        }
        return handled
    }

    /// Renders the horizontal scrolling list of chips representing
    /// unplaced pieces. Selected chips are highlighted.
    private var panelView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(game.pieces) { piece in
                    // Hide the piece once placed on the board
                    if piece.placedTargetId == nil {
                        PieceChipView(
                            piece: piece,
                            isSelected: piece.id == selectedPieceId && !useDragMode,
                            useDragMode: useDragMode,
                            onTap: {
                                // Toggle selection when tapping. In drag mode
                                // selection still highlights diagonals but does
                                // not trigger placement until drop.
                                if selectedPieceId == piece.id {
                                    selectedPieceId = nil
                                } else {
                                    selectedPieceId = piece.id
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    /// The UI allowing the player to input six letters for the main
    /// diagonal. Each cell is bound to an element of `game.mainDiagonal`.
    private var mainInputView: some View {
        VStack(spacing: 8) {
            Text("Enter the main diagonal")
                .font(.headline)
            HStack(spacing: 4) {
                ForEach(0..<6, id: \ .self) { index in
                    TextField("", text: Binding(
                        get: {
                            game.mainDiagonal[index] ?? ""
                        },
                        set: { newValue in
                            // Accept at most one character
                            let trimmed = newValue.uppercased().prefix(1)
                            game.mainDiagonal[index] = trimmed.isEmpty ? nil : String(trimmed)
                            // Advance focus
                            if !trimmed.isEmpty {
                                if index < 5 {
                                    focusedField = index + 1
                                } else {
                                    focusedField = nil
                                    // When all six letters entered call validation
                                    let values = game.mainDiagonal.map { $0 ?? "" }
                                    game.setMainDiagonal(values: values)
                                }
                            }
                        }
                    ))
                    .frame(width: 40, height: 50)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .keyboardType(.alphabet)
                    .focused($focusedField, equals: index)
                    .disableAutocorrection(true)
                    .autocapitalization(.allCharacters)
                }
            }
        }
        .padding(.top, 8)
    }
}