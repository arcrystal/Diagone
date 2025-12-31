import Foundation
import SwiftUI

@MainActor
public final class TestGameViewModel: ObservableObject {
    @Published public var started: Bool = false
    @Published public var testMessage: String = "test"

    private let storageKeyPrefix = "testgame"

    public init() {
        // Load any saved state if needed in the future
    }

    public func startGame() {
        started = true
    }
}
