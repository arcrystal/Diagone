import Foundation
import SwiftUI
import Combine

@MainActor
public final class RhymeAGramsViewModel: ObservableObject {
    @Published public var answers: [String] = ["", "", "", ""]
    @Published public var selectedSlot: Int = 0
    @Published public var started: Bool = false
    @Published public var finished: Bool = false
    @Published public var elapsedTime: TimeInterval = 0
    @Published public var finishTime: TimeInterval = 0
    @Published public var winBounceIndex: Int? = nil

    private(set) var engine: RhymeAGramsEngine
    private var timerCancellable: AnyCancellable?
    private var saveWorkItem: DispatchWorkItem?
    private var startDate: Date?
    private let storageKeyPrefix = "rhymeagrams"
    private var storageKey: String { "\(storageKeyPrefix)_state" }

    // MARK: - Lightweight per-day meta persistence
    private struct DailyMeta: Codable {
        var started: Bool
        var finished: Bool
        var elapsedTime: TimeInterval
        var finishTime: TimeInterval
        var lastUpdated: Date
    }

    private var metaKey: String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        let day = fmt.string(from: Date())
        return "\(storageKeyPrefix)_meta_\(day)"
    }

    private func loadDailyMeta() -> DailyMeta? {
        guard let data = UserDefaults.standard.data(forKey: metaKey) else { return nil }
        return try? JSONDecoder().decode(DailyMeta.self, from: data)
    }

    private func saveDailyMeta(started: Bool? = nil,
                               finished: Bool? = nil,
                               elapsedTime: TimeInterval? = nil,
                               finishTime: TimeInterval? = nil) {
        var current = loadDailyMeta() ?? DailyMeta(started: false, finished: false, elapsedTime: 0, finishTime: 0, lastUpdated: Date())
        if let s = started { current.started = s }
        if let f = finished { current.finished = f }
        if let e = elapsedTime { current.elapsedTime = e }
        if let ft = finishTime { current.finishTime = ft }
        current.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: metaKey)
        }
    }

    public init(date: Date = Date()) {
        let puzzle = RhymeAGramsPuzzleLibrary.loadPuzzle(for: date)
        self.engine = RhymeAGramsEngine(puzzle: puzzle)

        // Restore lightweight hub state
        let meta = self.loadDailyMeta()
        if let meta = meta {
            self.started = meta.started
            self.finished = meta.finished
            self.elapsedTime = meta.elapsedTime
            self.finishTime = meta.finishTime
        }

        // Restore game state
        if let savedState = loadSavedState() {
            self.engine = RhymeAGramsEngine(puzzle: puzzle, state: savedState)
            self.answers = savedState.answers
            self.selectedSlot = savedState.selectedSlot
        }
    }

    // MARK: - Game Actions
    public func startGame() {
        guard !started else { return }
        started = true
        startDate = Date()
        saveDailyMeta(started: true)
        startTimer()
    }

    public func resume() {
        guard started && !finished else { return }
        startTimer()
    }

    public func pause() {
        stopTimer()
        saveWorkItem?.cancel()
        saveState()
    }

    public func selectSlot(_ index: Int) {
        selectedSlot = index
        engine.selectSlot(index)
    }

    public func typeKey(_ key: String) {
        engine.appendLetter(key)
        answers = engine.state.answers
        debouncedSave()
        checkSolved()
    }

    public func deleteKey() {
        engine.deleteLetter()
        answers = engine.state.answers
        debouncedSave()
    }

    // Debounced save to avoid lag on every keystroke
    private func debouncedSave() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveState()
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    public func runWinSequence() {
        Task {
            for i in 0..<4 {
                try? await Task.sleep(nanoseconds: 350_000_000)
                withAnimation(.easeInOut(duration: 0.3)) {
                    winBounceIndex = i
                }
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                winBounceIndex = nil
            }
        }
    }

    private func checkSolved() {
        guard !finished && engine.isSolved else { return }
        finished = true
        finishTime = elapsedTime
        stopTimer()
        saveDailyMeta(finished: true, finishTime: finishTime)
        saveState()
        runWinSequence()
    }

    // MARK: - Timer
    private func startTimer() {
        guard timerCancellable == nil else { return }
        startDate = Date().addingTimeInterval(-elapsedTime)
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.startDate else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
                self.saveDailyMeta(elapsedTime: self.elapsedTime)
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    public var elapsedTimeString: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var correctAnswerIndices: Set<Int> {
        return engine.correctAnswerIndices
    }

    public var puzzle: RhymeAGramsPuzzle {
        return engine.puzzle
    }

    // MARK: - Persistence
    private func saveState() {
        if let data = try? JSONEncoder().encode(engine.state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadSavedState() -> RhymeAGramsState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(RhymeAGramsState.self, from: data)
    }
}
