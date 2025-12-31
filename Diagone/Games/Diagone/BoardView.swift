import SwiftUI
import UniformTypeIdentifiers

private struct TileBounceState { var scale: CGFloat = 1.0 }

private struct BoardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

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
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: BoardFrameKey.self,
                                           value: proxy.frame(in: .global))
                }
            )
            .onPreferenceChange(BoardFrameKey.self) { rect in
                if viewModel.boardFrameGlobal != rect {
                    viewModel.boardFrameGlobal = rect
                }
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
    
    @ViewBuilder
    private func makeCell(isMain: Bool,
                          isHover: Bool,
                          letter: String,
                          cellSize: CGFloat,
                          delay: Double) -> some View {
        let baseRect = Rectangle()
            .fill(isMain ? Color.mainDiagonal : Color.boardCell)
        let stroked = baseRect
            .overlay(Rectangle().stroke(Color.gridLine, lineWidth: 1))
        let withHover = stroked
            .overlay(
                Group {
                    if isHover {
                        Rectangle().fill(Color.hoverHighlight).allowsHitTesting(false)
                    }
                }
            )
        let withText = withHover
            .overlay(
                Group {
                    if !letter.isEmpty {
                        Text(letter)
                            .font(.system(size: cellSize * 0.5, weight: .bold))
                            .foregroundStyle(Color.letter)
                    }
                }
            )
        let framed = withText
            .frame(width: cellSize, height: cellSize)
            .compositingGroup()

        framed
            .keyframeAnimator(initialValue: TileBounceState(), trigger: viewModel.winWaveTrigger) { content, state in
                content.scaleEffect(state.scale)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.0, duration: delay)
                    SpringKeyframe(1.2, duration: 0.18, spring: .init(response: 0.36, dampingRatio: 0.62))
                    SpringKeyframe(1.0,  duration: 0.32, spring: .init(response: 0.40, dampingRatio: 0.72))
                }
            }
    }


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
                        // Precompute simple values to reduce expression complexity
                        let waveStep = r + c
                        let isMain = mainCells.contains(id)
                        let isHover = hoverCells.contains(id)
                        let letter = board[r][c]

                        // NEW: baseline + per-step
                        let baseDelay = 0.02    // 20ms so no tile has 0 delay
                        let stepDelay = 0.07
                        let delay = baseDelay + stepDelay * Double(waveStep)

                        makeCell(isMain: isMain,
                                 isHover: isHover,
                                 letter: letter,
                                 cellSize: cellSize,
                                 delay: delay)
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
