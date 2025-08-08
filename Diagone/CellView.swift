import SwiftUI

/// Displays a single cell in the 6×6 game grid. It shows any letter
/// currently placed, highlights the main diagonal with a blue stroke,
/// highlights eligible diagonals during piece selection with a yellow
/// backdrop, and handles tap gestures. The cell itself contains no
/// game logic – it delegates interactions back up through closures.
struct CellView: View {
    let cell: CellCoordinate
    let letter: String
    let isMain: Bool
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isHighlighted ? Color(UIColor.systemYellow).opacity(0.15) : Color.clear)
            Rectangle()
                .strokeBorder(borderColor, lineWidth: isMain ? 2 : 1)
            Text(letter)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var borderColor: Color {
        if isMain { return Color.blue }
        if isHighlighted { return Color(UIColor.systemYellow) }
        return Color.secondary.opacity(0.4)
    }

    private var accessibilityDescription: String {
        let row = cell.row + 1
        let col = cell.col + 1
        var desc = "Row \(row), Column \(col)"
        if isMain {
            desc += ", main diagonal"
        }
        if !letter.isEmpty {
            desc += ", contains letter \(letter)"
        }
        return desc
    }
}