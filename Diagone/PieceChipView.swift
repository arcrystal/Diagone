import SwiftUI

/// A pill‑shaped chip representing an individual letter sequence. Chips
/// reside in the side panel until placed on a diagonal. When tapped the
/// chip becomes selected and the board highlights all diagonals of
/// matching length. Selected state is indicated by a different
/// background colour. The chip is also accessible via VoiceOver.
struct PieceChipView: View {
    let piece: GamePiece
    let isSelected: Bool
    let useDragMode: Bool
    let onTap: () -> Void

    var body: some View {
        let chip = HStack(spacing: 4) {
            Text(piece.letters)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
            Text("\(piece.length)")
                .font(.system(size: 12, weight: .bold))
                .padding(4)
                .background(Color(UIColor.systemGray5))
                .clipShape(Circle())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color(UIColor.systemBackground).opacity(0.8))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
        .cornerRadius(12)

        Group {
            if useDragMode {
                chip
                    .onDrag {
                        // Provide the piece id as a plain text item so that
                        // drop targets can decode it later.
                        return NSItemProvider(object: piece.id.uuidString as NSString)
                    }
                    .onTapGesture {
                        // Still allow tap to toggle selection when dragging
                        onTap()
                    }
            } else {
                Button(action: onTap) {
                    chip
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(piece.letters), length \(piece.length)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}