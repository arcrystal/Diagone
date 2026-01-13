import SwiftUI

struct TumblePunsView: View {
    @ObservedObject var viewModel: TumblePunsViewModel
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
        ZStack {
            Color.boardCell.opacity(0.2)
                .ignoresSafeArea()

            if showHub {
                startHub
            } else {
                gameView
            }
        }
        .onAppear {
            if !viewModel.started {
                // Coming from loading screen - start the game and go directly to game
                viewModel.startGame()
                showHub = false
            } else {
                // Returning to paused or completed game - show hub
                showHub = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                if viewModel.started && !viewModel.finished {
                    viewModel.pause()
                    showHub = true
                }
            }
        }
        .onChange(of: viewModel.finished) { _, finished in
            if finished {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showHub = true
                }
            }
        }
    }

    // MARK: - Start Hub
    private var startHub: some View {
        VStack(spacing: 0) {
        
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.mainDiagonal)

                Text("TumblePuns")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Unscramble words and solve the punny definition")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
            }

            Spacer()

            // Bottom content - state-specific
            VStack(spacing: 16) {
                switch hubMode {
                case .notStarted:
                    Button(action: {
                        viewModel.startGame()
                        showHub = false
                    }) {
                        Text("Play")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.mainDiagonal)
                            .cornerRadius(12)
                    }

                case .inProgress:
                    Text("You're in the middle of today's puzzle.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(viewModel.elapsedTimeString)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()

                    Button(action: {
                        viewModel.resume()
                        showHub = false
                    }) {
                        Text("Resume")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.mainDiagonal)
                            .cornerRadius(12)
                    }

                    Button(action: onBackToHome) {
                        Text("Back to Home")
                            .font(.headline)
                            .foregroundColor(.mainDiagonal)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.mainDiagonal, lineWidth: 2)
                            )
                    }

                case .completed:
                    Text("Great job!")
                        .font(.title3.weight(.semibold))

                    Text("Time: \(String(format: "%02d:%02d", Int(viewModel.finishTime) / 60, Int(viewModel.finishTime) % 60))")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()

                    Text("Check back tomorrow for a new puzzle!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
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
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            Button(action: {
                viewModel.pause()
                showHub = true
            }) {
                Label("Back", systemImage: "chevron.backward")
                    .font(.headline)
            }

            Spacer()

            Text("TumblePuns")
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
    }

    // MARK: - Words Grid
    private var wordsGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                wordSection(index: 0)
                wordSection(index: 1)
            }
            HStack(spacing: 16) {
                wordSection(index: 2)
                wordSection(index: 3)
            }
        }
        .padding(.horizontal, 16)
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.boardCell)
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                        )
                        .offset(x: radius * cos(angle.radians), y: radius * sin(angle.radians))
                }
            }
            .frame(width: 85, height: 85)

            // Answer boxes
            HStack(spacing: 2) {
                ForEach(0..<word.solution.count, id: \.self) { letterIndex in
                    let userAnswer = viewModel.wordAnswers[index]
                    let displayLetter = letterIndex < userAnswer.count ? String(userAnswer[userAnswer.index(userAnswer.startIndex, offsetBy: letterIndex)]) : ""
                    let isShaded = word.shadedIndices.contains(letterIndex + 1)
                    let shouldBounce = viewModel.winBounceIndex == index

                    Text(displayLetter)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isCorrect ? .green : .primary)
                        .frame(width: 22, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isShaded ? Color.mainDiagonal.opacity(0.3) : Color.boardCell)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(
                                    isCorrect ? Color.green : (isSelected ? Color.mainDiagonal : Color.gray.opacity(0.4)),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .offset(y: shouldBounce ? -8 : 0)
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
            HStack(spacing: 4) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { offset, char in
                    if char == "_" {
                        let letterIndex = pattern.prefix(offset + 1).filter { $0 == "_" }.count - 1
                        let userAnswer = viewModel.finalAnswer
                        let displayLetter = letterIndex < userAnswer.count ? String(userAnswer[userAnswer.index(userAnswer.startIndex, offsetBy: letterIndex)]) : ""
                        let shouldBounce = viewModel.finalAnswerBounceIndex == letterIndex

                        Text(displayLetter)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 34, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.mainDiagonal.opacity(0.3))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(
                                        viewModel.isFinalAnswerSelected ? Color.mainDiagonal : Color.gray.opacity(0.4),
                                        lineWidth: viewModel.isFinalAnswerSelected ? 2 : 1
                                    )
                            )
                            .scaleEffect(shouldBounce ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: shouldBounce)
                    } else {
                        Text(String(char))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 12, height: 42)
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
        VStack(spacing: 4) {
            let rows = [
                ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
                ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
                ["Z", "X", "C", "V", "B", "N", "M"]
            ]

            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 3) {
                    if rowIndex == 1 {
                        Spacer().frame(width: 14)
                    } else if rowIndex == 2 {
                        Spacer().frame(width: 28)
                    }

                    ForEach(rows[rowIndex], id: \.self) { key in
                        Text(key)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(UIColor.systemGray4))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !viewModel.finished {
                                    viewModel.typeKey(key)
                                }
                            }
                    }

                    if rowIndex == 2 {
                        Image(systemName: "delete.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 42, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(UIColor.systemGray4))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !viewModel.finished {
                                    viewModel.deleteKey()
                                }
                            }
                    }

                    if rowIndex == 1 {
                        Spacer().frame(width: 14)
                    } else if rowIndex == 2 {
                        Spacer().frame(width: 28)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .opacity(viewModel.finished ? 0.5 : 1.0)
    }
}
