import SwiftUI
import UniformTypeIdentifiers

/// Visual representation of a draggable diagonal word chip. Each chip renders its
/// letters along a 45° diagonal to mirror the geometry of its destination on the
/// board. Chips scale up slightly and gain a shadow while dragging to provide
/// tactile feedback. When the game hasn’t started yet the chips are hidden.
struct ChipView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    let piece: GamePiece
    let cellSize: CGFloat
    var hidden: Bool

    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        Group {
            if !hidden {
                diagonalChip
            }
        }
    }

    private var diagonalChip: some View {
        HStack(spacing: 0) {
            ForEach(Array(piece.letters.enumerated()), id: \.offset) { index, ch in
                Text(String(ch))
                    .font(.system(size: cellSize * 0.6, weight: .bold))
                    .frame(width: cellSize, height: cellSize)
                    .background(RoundedRectangle(cornerRadius: cellSize * 0.15).fill(Color(.systemBackground)))
            }
        }
        .rotationEffect(.degrees(45))
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .shadow(radius: isDragging ? 6 : 3)
        .contentShape(Rectangle())                    // big hit area
        .highPriorityGesture(                         // start immediately
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { v in
                    if !isDragging {
                        isDragging = true
                        viewModel.beginDragging(pieceId: piece.id)
                    }
                    dragOffset = v.translation
                    viewModel.updateDrag(globalLocation: v.location)
                }
                .onEnded { _ in
                    viewModel.finishDrag()
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                        isDragging = false
                        dragOffset = .zero
                    }
                }
        )
        .offset(dragOffset)                           // follow finger
        .zIndex(isDragging ? 10 : 0)
    }
}

/// A view used as the drag preview for a chip. It mirrors the appearance of
/// `ChipView` but doesn’t participate in layout. Drag previews ignore
/// animations so we omit those here.
fileprivate struct ChipDragPreview: View {
    let piece: GamePiece
    let cellSize: CGFloat
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(Array(piece.letters.enumerated()), id: \.offset) { index, element in
                    let ch = String(element)
                    Text(ch)
                        .font(.system(size: cellSize * 0.6, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: cellSize, height: cellSize)
                        .background(
                            RoundedRectangle(cornerRadius: cellSize * 0.15, style: .continuous)
                                .fill(Color(.systemBackground))
                        )
                }
            }
            .rotationEffect(.degrees(-45))
        }
        .frame(width: CGFloat(piece.length) * cellSize * sqrt(2), height: CGFloat(piece.length) * cellSize * sqrt(2))
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
