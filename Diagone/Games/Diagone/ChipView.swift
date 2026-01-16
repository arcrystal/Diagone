import SwiftUI
import UniformTypeIdentifiers

/// Visual representation of a draggable diagonal word chip. Each chip renders its
/// letters in a diagonal staircase pattern with upright square tiles whose corners
/// touch. Chips scale up and spread apart while dragging for better visibility.
struct ChipView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    /// The piece this chip represents. Contains the letters and identifier.
    let piece: GamePiece
    /// Size of one board cell. Controls the size of the chip's letters.
    let cellSize: CGFloat
    /// Whether the chip should be hidden. Chips remain hidden until the player
    /// presses the start button.
    var hidden: Bool
    /// Internal state tracking whether the chip is currently being dragged.
    @State private var isDragging = false
    /// Offset applied during manual dragging
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        Group {
            if hidden {
                EmptyView()
            } else {
                let inactive = viewModel.isPaneChipInactive(piece.id)
                let tileSize = cellSize * 0.85
                // Step between tiles: when corners touch, step = tileSize * sqrt(2) / 2 ≈ 0.707 * tileSize
                // We use slightly less for a tighter look
                let step = tileSize * (isDragging ? 0.85 : 0.72)
                let totalSpan = step * CGFloat(piece.length - 1) + tileSize

                ZStack(alignment: .topLeading) {
                    ForEach(Array(piece.letters.enumerated()), id: \.offset) { index, element in
                        let ch = String(element)
                        Text(ch)
                            .font(.system(size: tileSize * 0.6, weight: .bold, design: .rounded))
                            .foregroundColor(.letter)
                            .frame(width: tileSize, height: tileSize)
                            .background(
                                RoundedRectangle(cornerRadius: tileSize * 0.15, style: .continuous)
                                    .fill(Color.boardCell)
                                    .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: tileSize * 0.15, style: .continuous)
                                    .stroke(Color.gridLine, lineWidth: 1)
                            )
                            .offset(
                                x: CGFloat(index) * step,
                                y: CGFloat(index) * step
                            )
                    }
                }
                .frame(width: totalSpan, height: totalSpan)
                .scaleEffect(isDragging ? 1.8 : 1.0)
                .offset(dragOffset)
                .shadow(color: .black.opacity(isDragging ? 0.18 : 0.06), radius: isDragging ? 8 : 3, x: 0, y: isDragging ? 4 : 1)
                .animation(.snappy(duration: 0.15), value: isDragging)
                .animation(nil, value: dragOffset)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                viewModel.beginDragging(pieceId: piece.id)
                            }
                            dragOffset = value.translation
                            viewModel.updateDrag(globalLocation: value.location)
                        }
                        .onEnded { _ in
                            viewModel.finishDrag()
                            withAnimation(.snappy(duration: 0.12)) {
                                isDragging = false
                                dragOffset = .zero
                            }
                        }
                )
                .onDisappear {
                    isDragging = false
                    dragOffset = .zero
                }
                .opacity(inactive ? 0.25 : 1.0)
                .allowsHitTesting(!inactive)
            }
        }
    }
}

/// A view used as the drag preview for a chip. It mirrors the appearance of
/// `ChipView` but doesn't participate in layout.
fileprivate struct ChipDragPreview: View {
    let piece: GamePiece
    let cellSize: CGFloat

    var body: some View {
        let tileSize = cellSize * 0.85
        let step = tileSize * 0.72
        let totalSpan = step * CGFloat(piece.length - 1) + tileSize

        ZStack(alignment: .topLeading) {
            ForEach(Array(piece.letters.enumerated()), id: \.offset) { index, element in
                let ch = String(element)
                Text(ch)
                    .font(.system(size: tileSize * 0.6, weight: .bold, design: .rounded))
                    .foregroundColor(.letter)
                    .frame(width: tileSize, height: tileSize)
                    .background(
                        RoundedRectangle(cornerRadius: tileSize * 0.15, style: .continuous)
                            .fill(Color.boardCell)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: tileSize * 0.15, style: .continuous)
                            .stroke(Color.gridLine, lineWidth: 1)
                    )
                    .offset(
                        x: CGFloat(index) * step,
                        y: CGFloat(index) * step
                    )
            }
        }
        .frame(width: totalSpan, height: totalSpan)
    }
}

/// A dummy drop delegate on the chip itself. Without this SwiftUI will not
/// correctly clear the dragging state on drop when dragging within the same
/// column. The delegate does nothing but is required to avoid a bug in
/// SwiftUI prior to iOS 18 where .onDrag would not reset `isDragging` for
/// items dropped onto themselves.
fileprivate struct DummyDropDelegate: DropDelegate {
    func performDrop(info: DropInfo) -> Bool { return false }
}
