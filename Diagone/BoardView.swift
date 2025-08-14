import SwiftUI
import UniformTypeIdentifiers

/// Renders the 6×6 game board. Displays individual cells with letters, highlights
/// for the main diagonal and drag feedback, and overlays drop targets on top of
/// the board grid. The board listens to the `GameViewModel` for state and
/// emits callbacks through drop delegates when pieces are dropped.
struct BoardView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    /// Optional row index to highlight during the win animation. When non‑nil
    /// the specified row is tinted with the accent colour.
    var highlightRow: Int?

    var body: some View {
        GeometryReader { geo in
            let side: CGFloat = min(geo.size.width, geo.size.height)
            let cellSize: CGFloat = side / 6.0

            ZStack {
                // --- your grid ---
                let engine = viewModel.engine
                let board  = engine.state.board
                let mainCells = Set(engine.state.mainDiagonal.cells)
                let hoverCells: Set<Cell> = {
                    if let tid = viewModel.dragHoverTargetId,
                       let t = engine.state.targets.first(where: { $0.id == tid }) {
                        return Set(t.cells)
                    }
                    return []
                }()

                VStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<6, id: \.self) { c in
                                let id = Cell(row: r, col: c)
                                Rectangle()
                                    .fill(mainCells.contains(id) ? Color.mainDiagonal : Color.boardCell)
                                    .overlay(Rectangle().stroke(Color.gridLine, lineWidth: 1))
                                    .overlay {
                                        if hoverCells.contains(id) {
                                            Rectangle().fill(Color.hoverHighlight).allowsHitTesting(false)
                                        }
                                    }
                                    .overlay {
                                        if !board[r][c].isEmpty {
                                            Text(board[r][c])
                                                .font(.system(size: cellSize * 0.5, weight: .bold))
                                                .foregroundStyle(Color.letter)
                                        }
                                    }
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .background(boardFrameReporter) // << capture the frame of THIS board
            .overlay {
                // show target hints but don't intercept drags while dragging
                ZStack {
                    ForEach(viewModel.engine.state.targets, id: \.id) { t in
                        DropTargetOverlay(target: t, cellSize: cellSize)
                            .environmentObject(viewModel)
                            .allowsHitTesting(false) // purely visual
                    }
                }
                .allowsHitTesting(viewModel.draggingPieceId == nil)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var boardFrameReporter: some View {
        GeometryReader { p in
            Color.clear
                .onAppear { viewModel.boardFrameGlobal = p.frame(in: .global) }
                .onChange(of: p.size, initial: true) { _, _ in
                    viewModel.boardFrameGlobal = p.frame(in: .global)
                }
        }
    }
}

/// A view representing an invisible drop area over a single diagonal. Handles
/// taps to remove placed pieces and forwards drop events to the view model via
/// a custom drop delegate. The overlay’s size and position are derived from
/// the target’s starting cell and its length.
fileprivate struct DropTargetOverlay: View {
    let target: GameTarget
    let cellSize: CGFloat
    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
        // Calculate bounding box for the diagonal. All diagonals run from top‑left
        // to bottom‑right so width and height are equal to the number of cells.
        let start = target.cells.first!
        let length = CGFloat(target.length)
        let size = cellSize * length
        // Position the overlay so that its top‑left corner aligns with the
        // starting cell of the diagonal. `position` uses the centre point so we
        // add half the size to both coordinates.
        let centerX = cellSize * (CGFloat(start.col) + length / 2.0)
        let centerY = cellSize * (CGFloat(start.row) + length / 2.0)
        return Rectangle()
            .fill(Color.clear)
            .frame(width: size, height: size)
            .position(x: centerX, y: centerY)
            .contentShape(Rectangle())
            .onTapGesture {
                // Return piece to panel if one is placed on this target
                if (viewModel.engine.state.targets.first(where: { $0.id == target.id })?.pieceId) != nil {
                    viewModel.removePiece(from: target.id)
                }
            }
    }
}

/// Drop delegate that manages drag and drop interactions for a single diagonal.
/// Restricts drops to valid targets based on the piece currently being dragged
/// and updates hover highlighting via the view model. When a drop occurs the
/// delegate forwards the placement to the view model. Invalid drops simply
/// cancel without modifying state.
fileprivate struct DiagonalDropDelegate: DropDelegate {
    let target: GameTarget
    @ObservedObject var viewModel: GameViewModel

    func validateDrop(info: DropInfo) -> Bool {
        // Allow a drop only if we know which piece is being dragged and the target
        // is in the valid list for that piece.
        guard let pieceId = viewModel.draggingPieceId else { return false }
        return viewModel.validTargets(for: pieceId).contains(target.id)
    }

    func dropEntered(info: DropInfo) {
        viewModel.dragEntered(targetId: target.id)
    }

    func dropExited(info: DropInfo) {
        viewModel.dragExited(targetId: target.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let pieceId = viewModel.draggingPieceId else { return false }
        let result = viewModel.handleDrop(pieceId: pieceId, onto: target.id)
        // End dragging regardless of outcome
        viewModel.endDragging()
        return result
    }
}
