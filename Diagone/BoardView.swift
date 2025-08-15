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
                // Grid + letters layer
                GridLayer(cellSize: cellSize)
                    .frame(width: side, height: side)
                    .background(boardFrameReporter)
                    .modifier(Shake(animatableData: CGFloat(viewModel.shakeTrigger)))

                // Targets overlay layer (tap + drop hit areas)
                TargetsOverlayLayer(cellSize: cellSize)
            }
            .overlay(alignment: .bottom) {
                if viewModel.showIncorrectFeedback {
                    IncorrectToastView()
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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

fileprivate struct GridLayer: View {
    @EnvironmentObject private var viewModel: GameViewModel
    let cellSize: CGFloat

    var body: some View {
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

        return VStack(spacing: 0) {
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
}

fileprivate struct TargetsOverlayLayer: View {
    @EnvironmentObject private var viewModel: GameViewModel
    let cellSize: CGFloat
    var body: some View {
        ZStack {
            ForEach(viewModel.engine.state.targets.sorted(by: { $0.length > $1.length }), id: \.id) { t in
                DropTargetOverlay(target: t, cellSize: cellSize)
                    .environmentObject(viewModel)
                    .allowsHitTesting(true)
            }
        }
        .allowsHitTesting(true)
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
            .contentShape({ () -> Path in
                let cellSize = self.cellSize
                var path = Path()
                for cell in target.cells {
                    let rect = CGRect(
                        x: CGFloat(cell.col) * cellSize,
                        y: CGFloat(cell.row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    ).insetBy(dx: cellSize * 0.12, dy: cellSize * 0.12)
                    path.addRect(rect)
                }
                return path
            }())
            .zIndex(10)
            .highPriorityGesture(
                TapGesture().onEnded {
                    viewModel.handleTap(on: target.id)
                }
            )
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

/// A gentle shake effect used for incorrect feedback (NYT-style)
fileprivate struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

/// A subtle, production-grade toast for incorrect puzzles.
fileprivate struct IncorrectToastView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.small)
            Text("Not quite—keep going")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 2, y: 1)
    }
}
