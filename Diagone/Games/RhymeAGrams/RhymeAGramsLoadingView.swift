import SwiftUI

struct RhymeAGramsLoadingView: View {
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

            PyramidIcon(size: 84)

            VStack(spacing: 6) {
                Text(formattedDate)
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .multilineTextAlignment(.center)

                Text("Find four 4-letter words from a pyramid of letters")
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

            VStack(spacing: 4) {
                Text(numberString).font(.subheadline).foregroundStyle(.secondary)
                Text("Edited by Diagone Team").font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formattedDate: String {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none
        return df.string(from: date)
    }

    private var numberString: String {
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
        let seed = Int(df.string(from: date)) ?? 0
        return "No. \(seed % 5000)"
    }
}

fileprivate struct PyramidIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Triangle background
            Triangle()
                .fill(Color.mainDiagonal.opacity(0.2))
                .frame(width: size, height: size * 0.866)  // Equilateral triangle ratio

            // Letter rows to suggest the game
            VStack(spacing: size * 0.08) {
                Text("A")
                    .font(.system(size: size * 0.15, weight: .semibold, design: .rounded))
                Text("BCD")
                    .font(.system(size: size * 0.12, weight: .semibold, design: .rounded))
                    .tracking(size * 0.06)
                Text("EFGHI")
                    .font(.system(size: size * 0.10, weight: .semibold, design: .rounded))
                    .tracking(size * 0.04)
                Text("JKLMNOP")
                    .font(.system(size: size * 0.08, weight: .semibold, design: .rounded))
                    .tracking(size * 0.03)
            }
            .foregroundColor(.primary)
            .offset(y: size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

fileprivate struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
