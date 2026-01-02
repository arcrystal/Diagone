import SwiftUI

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct RhymeAGramsView: View {
    @StateObject var viewModel: RhymeAGramsViewModel
    @Environment(\.scenePhase) private var scenePhase
    let onBackToHome: () -> Void

    @State private var showHub: Bool = true

    private enum HubMode { case notStarted, inProgress, completed }
    private var hubMode: HubMode {
        if viewModel.finished {
            return .completed
        } else if viewModel.started {
            return .inProgress
        } else {
            return .notStarted
        }
    }

    var body: some View {
        Group {
            if showHub {
                startHub
            } else {
                gameView
            }
        }
        .onAppear {
            showHub = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                if viewModel.started && !viewModel.finished {
                    viewModel.pause()
                    showHub = true
                }
            }
        }
        .onChange(of: viewModel.finished) { _, didFinish in
            if didFinish {
                UIApplication.shared.endEditing()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showHub = true
                }
            }
        }
    }

    // MARK: - Hub
    private var startHub: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: onBackToHome) {
                    Label("Back", systemImage: "chevron.backward")
                        .font(.headline)
                        .padding()
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 20)

            Text("RhymeAGrams")
                .font(.largeTitle.weight(.bold))

            switch hubMode {
            case .notStarted:
                VStack(spacing: 12) {
                    Text("Ready for today's puzzle?")
                        .font(.title3.weight(.semibold))
                    Button {
                        UIApplication.shared.endEditing()
                        viewModel.startGame()
                        showHub = false
                    } label: {
                        Text("Start")
                            .font(.headline)
                            .padding(.horizontal, 28).padding(.vertical, 12)
                            .background(Capsule().fill(Color.mainDiagonal))
                            .foregroundStyle(Color.white)
                    }
                }
            case .inProgress:
                VStack(spacing: 12) {
                    Text("You're in the middle of today's puzzle.")
                        .font(.title3.weight(.semibold))
                    Text("Elapsed: \(viewModel.elapsedTimeString)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button {
                        UIApplication.shared.endEditing()
                        viewModel.resume()
                        showHub = false
                    } label: {
                        Text("Resume")
                            .font(.headline)
                            .padding(.horizontal, 28).padding(.vertical, 12)
                            .background(Capsule().fill(Color.mainDiagonal))
                            .foregroundStyle(Color.white)
                    }
                }
            case .completed:
                VStack(spacing: 12) {
                    Text("Great job!")
                        .font(.title3.weight(.semibold))
                    Text("Time: \(String(format: "%02d:%02d", Int(viewModel.finishTime) / 60, Int(viewModel.finishTime) % 60))")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("Check back tomorrow for a new puzzle!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        UIApplication.shared.endEditing()
                        showHub = false
                        viewModel.runWinSequence()
                    } label: {
                        Text("View Today's Puzzle")
                            .font(.headline)
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(Capsule().fill(Color.primary))
                            .foregroundStyle(Color(UIColor.systemBackground))
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color.boardCell.opacity(0.2).ignoresSafeArea())
    }

    // MARK: - Game View
    private var gameView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    UIApplication.shared.endEditing()
                    viewModel.pause()
                    showHub = true
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .font(.headline)
                }

                Spacer()

                Text("RhymeAGrams")
                    .font(.headline)

                Spacer()

                if viewModel.started && !viewModel.finished {
                    HStack(spacing: 8) {
                        Text(viewModel.elapsedTimeString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        Button {
                            viewModel.pause()
                            showHub = true
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 75, alignment: .trailing)
                } else if viewModel.started && viewModel.finished {
                    Text(viewModel.elapsedTimeString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(width: 75, alignment: .trailing)
                } else {
                    Color.clear.frame(width: 75)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.boardCell.opacity(0.1))

            VStack(spacing: 20) {
                Spacer()

                // Pyramid
                PyramidView(letters: viewModel.puzzle.letters)
                    .padding(.horizontal)

                Spacer()

                // Answer slots
                AnswerSlotsView(
                    answers: viewModel.answers,
                    selectedSlot: viewModel.selectedSlot,
                    correctIndices: viewModel.correctAnswerIndices,
                    isSolved: viewModel.finished,
                    bounceIndex: viewModel.winBounceIndex,
                    onSelectSlot: { index in
                        viewModel.selectSlot(index)
                    }
                )
                .padding(.horizontal)

                Spacer()

                // Keyboard
                if !viewModel.finished {
                    KeyboardView(
                        onKeyTap: { key in
                            viewModel.typeKey(key)
                        },
                        onDelete: {
                            viewModel.deleteKey()
                        }
                    )
                    .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
        .background(Color.boardCell.opacity(0.2).ignoresSafeArea())
    }
}

// MARK: - Pyramid View
private struct PyramidView: View {
    let letters: [String]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, letter in
                        Text(String(letter))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.mainDiagonal.opacity(0.3))
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Answer Slots View
private struct AnswerSlotsView: View {
    let answers: [String]
    let selectedSlot: Int
    let correctIndices: Set<Int>
    let isSolved: Bool
    let bounceIndex: Int?
    let onSelectSlot: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                AnswerSlotRow(
                    answer: answers[index],
                    isSelected: selectedSlot == index && !isSolved,
                    isCorrect: correctIndices.contains(index),
                    isSolved: isSolved,
                    shouldBounce: bounceIndex == index,
                    onTap: {
                        onSelectSlot(index)
                    }
                )
            }
        }
    }
}

private struct AnswerSlotRow: View {
    let answer: String
    let isSelected: Bool
    let isCorrect: Bool
    let isSolved: Bool
    let shouldBounce: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                let letter = index < answer.count ? String(answer[answer.index(answer.startIndex, offsetBy: index)]) : ""
                Text(letter)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(letterColor)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(backgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(borderColor, lineWidth: isSelected ? 3 : 1)
                            )
                    )
                    .scaleEffect(shouldBounce ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: shouldBounce)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isSolved {
                onTap()
            }
        }
    }

    private var backgroundColor: Color {
        if isSolved && isCorrect {
            return Color.mainDiagonal.opacity(0.3)
        } else if isCorrect {
            return Color.green.opacity(0.2)
        } else {
            return Color.boardCell
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Color.mainDiagonal
        } else if isCorrect {
            return Color.green
        } else {
            return Color.gridLine
        }
    }

    private var letterColor: Color {
        if isSolved || isCorrect {
            return Color.primary
        } else {
            return Color.primary
        }
    }
}

// MARK: - Keyboard View
private struct KeyboardView: View {
    let onKeyTap: (String) -> Void
    let onDelete: () -> Void

    private let rows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 4) {
                    if rowIndex == 2 {
                        Spacer(minLength: 0)
                    }
                    ForEach(row, id: \.self) { key in
                        Text(key)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(UIColor.systemGray4))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onKeyTap(key)
                            }
                    }
                    if rowIndex == 2 {
                        Image(systemName: "delete.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(UIColor.systemGray4))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onDelete()
                            }
                    }
                }
            }
        }
    }
}
