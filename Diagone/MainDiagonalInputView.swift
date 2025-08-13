import SwiftUI

/// An inline input for the main diagonal. Displays six single‑character text
/// fields side by side. Each field enforces a single uppercase letter and moves
/// focus to the next field automatically as the user types. When all fields
/// change the parent view can observe and commit the letters into the engine.
struct MainDiagonalInputView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Binding var input: [String]
    let cellSize: CGFloat
    // A focus state to move between fields when typing
    @FocusState private var focusedIndex: Int?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<6) { index in
                ZStack {
                    // Background to resemble board cell
                    RoundedRectangle(cornerRadius: cellSize * 0.1, style: .continuous)
                        .fill(Color.mainDiagonal)
                        .frame(width: cellSize, height: cellSize)
                    TextField("", text: Binding(
                        get: { input[index] },
                        set: { newVal in
                            // Keep only the last character and uppercase it
                            let filtered = newVal.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                            if filtered.count > 1 {
                                input[index] = String(filtered.suffix(1))
                            } else {
                                input[index] = filtered
                            }
                            // Automatically move focus to the next field if we added a character
                            if !filtered.isEmpty && index < 5 {
                                focusedIndex = index + 1
                            }
                        }
                    ))
                    .font(.system(size: cellSize * 0.5, weight: .bold))
                    .foregroundColor(Color.letter)
                    .multilineTextAlignment(.center)
                    .focused($focusedIndex, equals: index)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .accessibilityLabel("Main diagonal letter \(index + 1)")
                }
            }
        }
        .padding(.vertical, 8)
        .onChange(of: input, initial: false) { old, new in
            // Commit the main diagonal to the engine whenever the letters change
            viewModel.commitMainInput()
        }
    }
}
