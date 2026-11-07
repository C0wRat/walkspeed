import SwiftUI
import WalkSpeedCore

/// Alert and sound settings.
struct SettingsView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(SpeedMonitor.self) private var monitor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var preferences = preferences
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Units", selection: $preferences.unit) {
                        ForEach(SpeedUnit.allCases) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    Picker("First beep", selection: $preferences.alertDelay) {
                        ForEach(Preferences.alertDelayOptions, id: \.self) { seconds in
                            Text(seconds == 0 ? "Straight away" : "After \(Int(seconds)) seconds").tag(seconds)
                        }
                    }
                    Picker("Repeat", selection: $preferences.repeatInterval) {
                        ForEach(Preferences.repeatIntervalOptions, id: \.self) { seconds in
                            Text("Every \(Int(seconds)) seconds").tag(seconds)
                        }
                    }
                } header: {
                    Text("Alerts")
                } footer: {
                    Text("How long you have to be over your limit before the first beep, and how often it beeps again while you stay over.")
                }

                Section {
                    Toggle("Lower music while beeping", isOn: $preferences.lowersMusic)
                    VStack(alignment: .leading) {
                        Text("Beep volume")
                        Slider(value: $preferences.beepVolume, in: 0.2...1) {
                            Text("Beep volume")
                        } minimumValueLabel: {
                            Image(systemName: "speaker.fill")
                        } maximumValueLabel: {
                            Image(systemName: "speaker.wave.3.fill")
                        }
                    }
                    HStack {
                        Text("Try the alerts")
                        Spacer()
                        ForEach(AlertLevel.allCases, id: \.self) { level in
                            Button {
                                monitor.playTestBeep(level)
                            } label: {
                                Text(level.beepCount.formatted())
                                    .monospacedDigit()
                                    .frame(minWidth: 20)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Play the \(level.beepCount)-beep alert")
                        }
                    }
                } header: {
                    Text("Sound")
                } footer: {
                    Text("One beep means you're just over your limit, two means clearly over, three means well over. Beeps play at your media volume, through headphones when they're connected.")
                }

                Section("About") {
                    Text("WalkSpeed measures your speed with GPS, so it works best outdoors. Alerts pause above \(vehicleSpeedText), when you're probably not walking.")
                    Text("While WalkSpeed is monitoring, iOS shows a blue location indicator. Stop monitoring when your walk is over to save battery.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var vehicleSpeedText: String {
        let speed = AlertConfiguration(limit: Preferences.defaultLimit).vehicleSpeed
        let value = Int(preferences.unit.value(fromMetresPerSecond: speed).rounded())
        return "\(value) \(preferences.unit.symbol)"
    }
}
