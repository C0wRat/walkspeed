import SwiftData
import SwiftUI

@main
struct WalkSpeedApp: App {
    @State private var preferences: Preferences
    @State private var monitor: SpeedMonitor
    private let history = WalkHistory()

    init() {
        let preferences = Preferences()
        _preferences = State(initialValue: preferences)
        _monitor = State(initialValue: SpeedMonitor(preferences: preferences))
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
