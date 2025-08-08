import SwiftUI

/// A simple settings interface allowing the player to toggle between
/// tap‑to‑place and drag‑and‑drop modes. Toggling updates the bound
/// boolean in the parent view. Additional options could be added
/// here, such as enabling hints or reduced motion.
struct SettingsView: View {
    @Binding var useDragMode: Bool

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Interaction")) {
                    Toggle("Use drag & drop", isOn: $useDragMode)
                        .accessibilityLabel(useDragMode ? "Drag and drop enabled" : "Drag and drop disabled")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}