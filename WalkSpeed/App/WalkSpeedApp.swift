import SwiftData
import SwiftUI

@main
struct WalkSpeedApp: App {
    @State private var preferences: Preferences
    @State private var monitor: SpeedMonitor
    private let history: WalkHistory

    init() {
        let preferences = Preferences()
        let history = WalkHistory()
        self.history = history
        _preferences = State(initialValue: preferences)
        _monitor = State(initialValue: SpeedMonitor(preferences: preferences, history: history))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(preferences)
                .environment(monitor)
        }
        .modelContainer(history.container)
    }
}
