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
        // A zero‑footprint keyboard proxy that becomes first responder
        KeyboardProxy(
            isActive: .constant(viewModel.showMainInput),
            onInsert: { ch in
                // Accept only A–Z characters
                guard let scalar = ch.unicodeScalars.first,
                      CharacterSet.uppercaseLetters.contains(scalar) || CharacterSet.lowercaseLetters.contains(scalar) else { return }
                let up = ch.uppercased()
                if let idx = input.firstIndex(where: { $0.isEmpty }) {
                    input[idx] = up
                }
                viewModel.commitMainInput()
            },
            onDelete: {
                if let idx = (0..<input.count).reversed().first(where: { !input[$0].isEmpty }) {
                    input[idx] = ""
                    viewModel.commitMainInput()
                }
            }
        )
        .frame(width: 0, height: 0)
        .opacity(0.01)
        .accessibilityHidden(true)
        .onChange(of: viewModel.showMainInput, initial: false) { _, newValue in
            // Toggle first responder on state changes
            KeyboardProxyManager.shared.setActive(newValue)
        }
        .onAppear {
            KeyboardProxyManager.shared.setActive(viewModel.showMainInput)
        }
    }
}

// MARK: - Keyboard Proxy (UIKit bridge)
private final class KeyboardProxyManager {
    static let shared = KeyboardProxyManager()
    private weak var proxyView: ProxyView?
    func register(_ view: ProxyView) { proxyView = view }
    func setActive(_ active: Bool) {
        if active {
            proxyView?.becomeFirstResponder()
        } else {
            proxyView?.resignFirstResponder()
        }
    }
}

private struct KeyboardProxy: UIViewRepresentable {
    let isActive: Binding<Bool>
    let onInsert: (String) -> Void
    let onDelete: () -> Void

    func makeUIView(context: Context) -> ProxyView {
        let v = ProxyView()
        v.onInsert = onInsert
        v.onDelete = onDelete
        v.keyboardType = .asciiCapable
        v.autocorrectionType = .no
        v.autocapitalizationType = .allCharacters
        KeyboardProxyManager.shared.register(v)
        return v
    }

    func updateUIView(_ uiView: ProxyView, context: Context) {
        if isActive.wrappedValue {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
}

private final class ProxyView: UIView, UIKeyInput, UITextInputTraits {
    var hasText: Bool = false
    var onInsert: ((String) -> Void)?
    var onDelete: (() -> Void)?

    // UITextInputTraits
    var keyboardType: UIKeyboardType = .asciiCapable
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .allCharacters
    var enablesReturnKeyAutomatically: Bool = false
    var returnKeyType: UIReturnKeyType = .default

    override var canBecomeFirstResponder: Bool { true }

    func insertText(_ text: String) {
        guard !text.isEmpty else { return }
        if text == "\n" { return } // ignore returns
        onInsert?(text)
    }

    func deleteBackward() {
        onDelete?()
    }
}
