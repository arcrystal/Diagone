import SwiftUI
import UniformTypeIdentifiers

/// Renders the 6×6 game board. Displays individual cells with letters, highlights
/// for the main diagonal and drag feedback, and overlays drop targets on top of
/// the board grid. The board listens to the `GameViewModel` for state and
/// emits callbacks through drop delegates when pieces are dropped.
struct BoardView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    var highlightRow: Int?

    var body: some View {
        GeometryReader { geo in
            let side: CGFloat = min(geo.size.width, geo.size.height)
            let cell: CGFloat = side / 6.0

            // Pull state into locals (guides the type checker)
            let engine = viewModel.engine
            let board = engine.state.board
            let mainCells = Set(engine.state.mainDiagonal.cells)

            let hoverSet: Set<Cell> = {
                guard let tid = viewModel.dragHoverTargetId,
                      let t = engine.state.targets.first(where: { $0.id == tid }) else { return [] }
                return Set(t.cells)
            }()

            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { c in
                            let cellId = Cell(row: r, col: c)
                            cellView(
                                size: cell,
                                letter: board[r][c],
                                isMain: mainCells.contains(cellId),
                                isHover: hoverSet.contains(cellId),
                                isRowHighlighted: highlightRow == r
                            )
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            // Drop target overlays drawn once, not per-cell
            .overlay {
                ZStack {
                    ForEach(engine.state.targets, id: \.id) { t in
                        DropTargetOverlay(target: t, cellSize: cell)
                            .environmentObject(viewModel)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(
            GeometryReader { p in
                Color.clear
                    .onChange(of: p.size, initial: false) { _, _ in
                        viewModel.boardFrameGlobal = p.frame(in: .global)
                    }
            }
        )
    }

    @ViewBuilder
    private func cellView(size: CGFloat,
                          letter: String,
                          isMain: Bool,
                          isHover: Bool,
                          isRowHighlighted: Bool) -> some View {
        Rectangle()
            .fill(isRowHighlighted ? Color.accent
                  : (isMain ? Color.mainDiagonal : Color.boardCell))
            .overlay(Rectangle().stroke(Color.gridLine, lineWidth: 1))
            .overlay {
                if isHover { Rectangle().fill(Color.hoverHighlight) }
            }
            .overlay {
                if !letter.isEmpty {
                    Text(letter)
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(Color.letter)
                }
            }
            .frame(width: size, height: size)
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
            .onDrop(of: [UTType.text], delegate: DiagonalDropDelegate(target: target, viewModel: viewModel))
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
