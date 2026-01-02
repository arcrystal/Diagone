import SwiftUI

struct TumblePunsView: View {
    @ObservedObject var viewModel: TumblePunsViewModel
    let onBackToHome: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.95)
                .ignoresSafeArea()

            if !viewModel.started {
                startHub
            } else if viewModel.finished {
                completedHub
            } else {
                gameView
            }
        }
        .onAppear {
            if viewModel.started && !viewModel.finished {
                viewModel.resume()
            }
        }
        .onDisappear {
            if viewModel.started && !viewModel.finished {
                viewModel.pause()
            }
        }
    }

    // MARK: - Start Hub
    private var startHub: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "circle.grid.3x3.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.2, green: 0.3, blue: 0.5))

            Text("TumblePuns")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Unscramble words and solve the punny definition")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button(action: { viewModel.startGame() }) {
                Text("Play")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.2, green: 0.3, blue: 0.5))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Completed Hub
    private var completedHub: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Puzzle Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Time: \(viewModel.elapsedTimeString)")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onBackToHome) {
                Text("Back to Home")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.2, green: 0.3, blue: 0.5))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Game View
    private var gameView: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView {
                VStack(spacing: 24) {
                    wordsGrid
                    definitionSection
                    finalAnswerSection
                    keyboardView
                }
                .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: onBackToHome) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.2, green: 0.3, blue: 0.5))
            }

            Spacer()

            Text("TumblePuns")
                .font(.headline)

            Spacer()

            Text(viewModel.elapsedTimeString)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(red: 0.97, green: 0.97, blue: 0.95))
    }

    // MARK: - Words Grid
    private var wordsGrid: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                wordSection(index: 0)
                wordSection(index: 1)
            }
            HStack(spacing: 20) {
                wordSection(index: 2)
                wordSection(index: 3)
            }
        }
        .padding(.horizontal, 20)
    }

    private func wordSection(index: Int) -> some View {
        let word = viewModel.puzzle.words[index]
        let isCorrect = viewModel.correctWordIndices.contains(index)
        let isSelected = viewModel.selectedWordIndex == index

        return VStack(spacing: 10) {
            // Scrambled letters arranged in a circle
            ZStack {
                ForEach(Array(word.scrambled.enumerated()), id: \.offset) { offset, letter in
                    let angle = Angle(degrees: Double(offset) * (360.0 / Double(word.scrambled.count)) - 90)
                    let radius: CGFloat = 30

                    Text(String(letter))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.2, blue: 0.4))
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                        )
                        .offset(x: radius * cos(angle.radians), y: radius * sin(angle.radians))
                }
            }
            .frame(width: 75, height: 75)

            // Answer boxes
            HStack(spacing: 2) {
                ForEach(0..<word.solution.count, id: \.self) { letterIndex in
                    let userAnswer = viewModel.wordAnswers[index]
                    let displayLetter = letterIndex < userAnswer.count ? String(userAnswer[userAnswer.index(userAnswer.startIndex, offsetBy: letterIndex)]) : ""
                    let isShaded = word.shadedIndices.contains(letterIndex + 1)
                    let shouldBounce = viewModel.winBounceIndex == index

                    Text(displayLetter)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isCorrect ? Color.green.opacity(0.8) : Color(red: 0.1, green: 0.2, blue: 0.4))
                        .frame(width: 20, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isShaded ? Color(red: 0.95, green: 0.85, blue: 0.6) : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(
                                    isCorrect ? Color.green.opacity(0.8) : (isSelected ? Color(red: 0.1, green: 0.2, blue: 0.4) : Color.gray.opacity(0.4)),
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                        )
                        .offset(y: shouldBounce ? -6 : 0)
                        .animation(.easeInOut(duration: 0.3), value: shouldBounce)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !viewModel.finished {
                    viewModel.selectWord(index)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Definition Section
    private var definitionSection: some View {
        VStack(spacing: 6) {
            Text("Definition:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(viewModel.puzzle.definition)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Final Answer Section
    private var finalAnswerSection: some View {
        VStack(spacing: 8) {
            Text("Final Answer")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            // Shaded letters hint (only show when all words are solved)
            if viewModel.areWordsSolved {
                Text("Shaded letters: \(viewModel.shadedLetters)")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }

            // Answer input boxes with dashes
            let pattern = viewModel.puzzle.answerPattern
            HStack(spacing: 3) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { offset, char in
                    if char == "_" {
                        let letterIndex = pattern.prefix(offset + 1).filter { $0 == "_" }.count - 1
                        let userAnswer = viewModel.finalAnswer
                        let displayLetter = letterIndex < userAnswer.count ? String(userAnswer[userAnswer.index(userAnswer.startIndex, offsetBy: letterIndex)]) : ""

                        Text(displayLetter)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.1, green: 0.2, blue: 0.4))
                            .frame(width: 24, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(red: 0.95, green: 0.85, blue: 0.6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(
                                        viewModel.isFinalAnswerSelected ? Color(red: 0.1, green: 0.2, blue: 0.4) : Color.gray.opacity(0.4),
                                        lineWidth: viewModel.isFinalAnswerSelected ? 1.5 : 1
                                    )
                            )
                    } else {
                        Text(String(char))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 8, height: 30)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !viewModel.finished {
                    viewModel.selectFinalAnswer()
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Keyboard
    private var keyboardView: some View {
        VStack(spacing: 5) {
            let rows = [
                ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
                ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
                ["Z", "X", "C", "V", "B", "N", "M"]
            ]

            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 3) {
                    if rowIndex == 1 {
                        Spacer().frame(width: 12)
                    } else if rowIndex == 2 {
                        Spacer().frame(width: 24)
                    }

                    ForEach(rows[rowIndex], id: \.self) { key in
                        Text(key)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.1, green: 0.2, blue: 0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.typeKey(key)
                            }
                    }

                    if rowIndex == 2 {
                        Image(systemName: "delete.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.1, green: 0.2, blue: 0.4))
                            .frame(width: 44, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.deleteKey()
                            }
                    }

                    if rowIndex == 1 {
                        Spacer().frame(width: 12)
                    } else if rowIndex == 2 {
                        Spacer().frame(width: 24)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
