import SwiftUI
import WalkSpeedCore

/// Totals for the running or the last monitoring session.
struct SessionSummary: View {
    var session: WalkSession
    /// When the session stopped, or `nil` while it's running.
    var endDate: Date?
    var unit: SpeedUnit

    var body: some View {
        TimelineView(.periodic(from: session.startDate, by: 1)) { context in
            let now = endDate ?? context.date
            HStack(spacing: 0) {
                stat("Time", value: Self.format(session.duration(at: now)))
                divider
                stat("Top speed", value: session.topSpeed.map { unit.formatted($0) } ?? "–")
                divider
                stat("Over limit", value: Self.format(session.timeOverLimit))
                divider
                stat("Alerts", value: session.alertCount.formatted())
            }
        }
        .padding(.vertical, 14)
        .background(.background.secondary, in: .rect(cornerRadius: 24))
    }

    private var divider: some View {
        Divider().frame(height: 32)
    }

    private func stat(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private static func format(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded(.down))
            .formatted(.time(pattern: seconds >= 3_600 ? .hourMinuteSecond : .minuteSecond))
    }
}
