import SwiftUI

struct TestGameView: View {
    @StateObject var viewModel: TestGameViewModel
    let onBackToHome: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Test Game")
                    .font(.title).bold()
                Spacer()
                Button {
                    onBackToHome()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .font(.headline)
                }
            }
            .padding(.horizontal)

            Spacer()

            Text(viewModel.testMessage)
                .font(.largeTitle)

            Text("This is a test game placeholder")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.vertical)
        .background(Color(UIColor.systemGray6).ignoresSafeArea())
    }
}
