//
//  PlayMoreView.swift
//  Diagone
//
//  Created by Alex Crystal on 8/26/25.
//

import SwiftUI

struct PlayMoreView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: GameViewModel

    let startDate: Date
    let columns: Int
    let onSelect: (Date) -> Void
    let onCancel: () -> Void

    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: max(1, columns))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: gridItems, spacing: 12) {
                    ForEach(generateDates(from: startDate), id: \.self) { date in
                        Button {
                            onSelect(date)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                Text(formatted(date))
                                    .font(.headline)
                                    .padding(.vertical, 16)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(height: 70)
                        .accessibilityLabel(archiveA11yLabel(for: date))
                    }
                }
                .padding(16)
            }
            .navigationTitle("Play an Earlier Puzzle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return df.string(from: date)
    }

    private func archiveA11yLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .full
        return "Play puzzle for \(df.string(from: date))"
    }

    // Generate dates in reverse chronological order (today, yesterday, …)
    private func generateDates(from start: Date, limit: Int = 60) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        for i in 0..<limit {
            if let d = calendar.date(byAdding: .day, value: -i, to: start) {
                dates.append(d)
            }
        }
        return dates
    }
}
