import SwiftUI
import UniformTypeIdentifiers

/// Visual representation of a draggable diagonal word chip. Each chip renders its
/// letters along a 45° diagonal to mirror the geometry of its destination on the
/// board. Chips scale up slightly and gain a shadow while dragging to provide
/// tactile feedback. When the game hasn’t started yet the chips are hidden.
struct ChipView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    /// The piece this chip represents. Contains the letters and identifier.
    let piece: GamePiece
    /// Size of one board cell. Controls the size of the chip’s letters and
    /// the diagonal footprint.
    let cellSize: CGFloat
    /// Whether the chip should be hidden. Chips remain hidden until the player
    /// presses the start button.
    var hidden: Bool
    /// Internal state tracking whether the chip is currently being dragged. Used
    /// to animate the scale and shadow.
    @State private var isDragging = false
    /// Offset applied during manual dragging
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        Group {
            if hidden {
                EmptyView()
            } else {
                let inactive = viewModel.isPaneChipInactive(piece.id)
                // Wrap in a ZStack so rotation doesn’t clip the chip
                ZStack {
                    // Render letters in an HStack; we rotate the entire stack to
                    // achieve the diagonal orientation. We apply no spacing
                    // between letters so they sit flush along the diagonal.
                    HStack(spacing: isDragging ? 0.4 * cellSize : 0) {
                        ForEach(Array(piece.letters.enumerated()), id: \.offset) { index, element in
                            let ch = String(element)
                            Text(ch)
                                .font(.system(size: cellSize * 0.9, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: cellSize, height: cellSize)
                                .rotationEffect(.degrees(-45)) // undo rotation for text
                                .background(
                                    isDragging ? nil :
                                    RoundedRectangle(cornerRadius: cellSize * 0.15, style: .continuous)
                                        .fill(Color(.systemBackground))
                                )
                                
                        }
                    }
                    .rotationEffect(.degrees(45))
                }
                .frame(width: CGFloat(piece.length) * cellSize * sqrt(2), height: CGFloat(piece.length) * cellSize * sqrt(2))
                .scaleEffect(isDragging ? 4.0 : 1.8) // resize chips
                .offset(dragOffset)
                .shadow(color: Color.black.opacity(isDragging ? 0.3 : 0.15), radius: isDragging ? 6 : 4, x: 0, y: isDragging ? 4 : 2)
                .animation(nil, value: dragOffset)
                // Custom drag gesture that begins immediately and updates the view model
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
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                                isDragging = false
                                dragOffset = .zero
                            }
                        }
                )
                .onDisappear {
                    // Reset dragging state on disappear
                    isDragging = false
                    dragOffset = .zero
                }
                .opacity(inactive ? 0.2 : 1.0)
                .allowsHitTesting(!inactive)
            }
        }
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
                        .rotationEffect(.degrees(-45))
                }
            }
            .rotationEffect(.degrees(45))
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
