//
//  RootCoordinatorView.swift
//  Diagone
//
//  Created by Alex Crystal on 8/18/25.
//

import SwiftUI

struct RootCoordinatorView: View {
    enum Route { case loading, game }

    @State private var route: Route = .loading
    @StateObject private var viewModel: GameViewModel

    init(date: Date) {
        _viewModel = StateObject(wrappedValue: GameViewModel(engine: GameEngine(puzzleDate: date)))
    }

    var body: some View {
        Group {
            switch route {
            case .loading:
                LoadingPuzzleView(
                    date: Date(),
                    onStart: {
                        viewModel.startGame()       // identical to your old Start button
                        route = .game               // replace the screen
                    }
                )
            case .game:
                ContentView(viewModel: viewModel)  // same instance travels to the game
            }
        }
    }
}
