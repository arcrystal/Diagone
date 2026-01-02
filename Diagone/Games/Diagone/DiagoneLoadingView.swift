import SwiftUI

struct DiagoneLoadingView: View {
    let date: Date
    let onStart: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.backward")
                        .font(.headline)
                        .padding()
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 80)
            GridIcon6x6(size: 84)

            VStack(spacing: 6) {
                Text(formattedDate)
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .multilineTextAlignment(.center)

                Text("Drag and drop diagonals to spell six horizontal words")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }

            Button {
                onStart()   // this triggers startGame + view swap
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

fileprivate struct GridIcon6x6: View {
    let size: CGFloat
    var body: some View {
        let cell = size / 6.0
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { c in
                        let isMain = (r == c)
                        Rectangle()
                            .fill(isMain ? Color.mainDiagonal : Color.boardCell)
                            .overlay(Rectangle().stroke(Color.gridLine, lineWidth: 0.75))
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.gridLine, lineWidth: 1))
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
