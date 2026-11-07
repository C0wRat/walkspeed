import SwiftUI
import WalkSpeedCore

/// The main screen: the live speed, the limit and the start button.
struct ContentView: View {
    @Environment(SpeedMonitor.self) private var monitor
    @Environment(Preferences.self) private var preferences
    @State private var isShowingSettings = false

    var body: some View {
        @Bindable var preferences = preferences
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AccessBanner(access: monitor.access)
                    SpeedGauge(
                        speed: monitor.speed,
                        limit: preferences.limit,
                        unit: preferences.unit,
                        zone: monitor.zone
                    )
                    .frame(maxWidth: 320)
                    .keyframeAnimator(initialValue: 1.0, trigger: monitor.session?.alertCount) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        SpringKeyframe(1.05, duration: 0.12)
                        SpringKeyframe(1.0, duration: 0.35)
                    }
                    statusView
                    LimitControl(limit: $preferences.limit, unit: preferences.unit)
                    if let session = monitor.session {
                        SessionSummary(session: session, endDate: monitor.sessionEndDate, unit: preferences.unit)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                startStopControls
            }
            .background {
                background
            }
            .navigationTitle("WalkSpeed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sensoryFeedback(.warning, trigger: monitor.session?.alertCount)
        }
    }

    private var statusView: some View {
        let status = status
        return VStack(spacing: 8) {
            Label(status.title, systemImage: status.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(status.color)
                .multilineTextAlignment(.center)
            if monitor.isMonitoring {
                SensorBadges(gps: monitor.signal, isPedometerActive: monitor.isPedometerActive)
            }
        }
        .animation(.default, value: monitor.zone)
        .animation(.default, value: monitor.isMonitoring)
    }

    private var status: (title: LocalizedStringKey, systemImage: String, color: Color) {
        guard monitor.isMonitoring else {
            return ("Ready when you are", "figure.walk", .secondary)
        }
        switch monitor.zone {
        case .unknown:
            return ("Finding your speed…", "location.magnifyingglass", .secondary)
        case .comfortable:
            return ("Nice and steady", "checkmark.circle.fill", .accentColor)
        case .nearLimit:
            return ("Close to your limit", "exclamationmark.circle.fill", .orange)
        case .overLimit:
            return ("Slow down", "tortoise.fill", .red)
        case .vehicle:
            return ("Too fast for walking, alerts paused", "car.fill", .secondary)
        }
    }

    private var startStopControls: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.snappy) {
                    if monitor.isMonitoring {
                        monitor.stop()
                    } else {
                        monitor.start()
                    }
                }
            } label: {
                Label(
                    monitor.isMonitoring ? "Stop" : "Start",
                    systemImage: monitor.isMonitoring ? "stop.fill" : "figure.walk"
                )
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(monitor.isMonitoring ? .red : .accentColor)
            .disabled(monitor.access == .denied || monitor.access == .restricted)
            .sensoryFeedback(.impact(weight: .medium), trigger: monitor.isMonitoring)

            Text(monitor.isMonitoring
                ? "Keeps running when you lock your phone."
                : "Beeps play over your music when you go too fast.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    /// A wash of the zone's colour at the top of the screen.
    private var background: some View {
        LinearGradient(
            colors: [monitor.isMonitoring ? monitor.zone.tint.opacity(0.25) : .clear, .clear],
            startPoint: .top,
            endPoint: .center
        )
        .animation(.easeInOut(duration: 0.6), value: monitor.zone)
        .animation(.easeInOut(duration: 0.6), value: monitor.isMonitoring)
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}

#Preview {
    let preferences = Preferences(defaults: UserDefaults(suiteName: "preview") ?? .standard)
    ContentView()
        .environment(preferences)
        .environment(SpeedMonitor(preferences: preferences))
}
