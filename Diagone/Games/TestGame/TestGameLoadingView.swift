import SwiftUI

struct TestGameLoadingView: View {
    let date: Date
    let onStart: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding()
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 80)

            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 84))
                .foregroundColor(.primary)

            VStack(spacing: 6) {
                Text(formattedDate)
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .multilineTextAlignment(.center)

                Text("A simple test game")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }

            Button {
                onStart()
            } label: {
                Text("Play")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Color.primary))
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGray6))
    }

    private var formattedDate: String {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none
        return df.string(from: date)
    }
}
