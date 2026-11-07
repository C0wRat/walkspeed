import Charts
import SwiftUI
import WalkSpeedCore

/// The summary of a walk: its route, totals and speed over time.
struct WalkSummaryView: View {
    let walk: Walk

    @Environment(Preferences.self) private var preferences

    var body: some View {
        let summary = walk.summary
        let unit = preferences.unit
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                routeSection
                    .frame(height: 280)
                    .clipShape(.rect(cornerRadius: 24))
                verdict(for: summary, unit: unit)
                stats(for: summary, unit: unit)
                let trace = walk.speedTrace
                if !trace.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speed")
                            .font(.headline)
                        SpeedChart(trace: trace, limit: summary.limit, unit: unit)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(summary.startDate.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var routeSection: some View {
        if walk.routePointCount > 1 {
            RouteMap(route: walk.route)
        } else {
            ZStack {
                Rectangle().fill(.background.secondary)
                VStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No GPS route")
                        .font(.headline)
                    Text("This walk was measured with the pedometer, probably indoors.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }

    private func verdict(for summary: WalkSummary, unit: SpeedUnit) -> some View {
        let limit = WalkFormat.speed(summary.limit, unit: unit)
        let isClean = summary.timeOverLimit < 1
        return Label {
            if isClean {
                Text("You stayed under \(limit) the whole walk.")
            } else {
                Text("Over \(limit) for \(WalkFormat.duration(summary.timeOverLimit)), \(summary.fractionOverLimit.formatted(.percent.precision(.fractionLength(0)))) of the walk.")
            }
        } icon: {
            Image(systemName: isClean ? "checkmark.circle.fill" : "tortoise.fill")
                .foregroundStyle(isClean ? Color.accentColor : .red)
        }
        .font(.headline)
    }

    private func stats(for summary: WalkSummary, unit: SpeedUnit) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "Distance", systemImage: "point.topleft.down.to.point.bottomright.curvepath", value: WalkFormat.distance(summary.distance, unit: unit))
            StatTile(title: "Time", systemImage: "clock", value: WalkFormat.duration(summary.duration))
            StatTile(title: "Average", systemImage: "gauge.with.dots.needle.33percent", value: WalkFormat.speed(summary.averageSpeed, unit: unit))
            StatTile(title: "Top speed", systemImage: "hare", value: WalkFormat.speed(summary.topSpeed, unit: unit))
            StatTile(title: "Over limit", systemImage: "exclamationmark.triangle", value: WalkFormat.duration(summary.timeOverLimit))
            StatTile(title: "Alerts", systemImage: "speaker.wave.2", value: summary.alertCount.formatted())
            if let steps = summary.steps {
                StatTile(title: "Steps", systemImage: "shoeprints.fill", value: steps.formatted())
            }
            StatTile(title: "Limit", systemImage: "gauge.with.needle", value: WalkFormat.speed(summary.limit, unit: unit))
        }
    }
}

/// One statistic in the summary grid.
private struct StatTile: View {
    var title: LocalizedStringKey
    var systemImage: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

/// Speed over the walk, with the limit as a dashed line and the stretches
/// over it marked in red.
struct SpeedChart: View {
    var trace: [SpeedTrace.Point]
    var limit: Double
    var unit: SpeedUnit

    var body: some View {
        let top = max(trace.map(\.speed).max() ?? 0, limit)
        Chart {
            ForEach(Array(trace.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Minutes", point.offset / 60),
                    y: .value("Speed", unit.value(fromMetresPerSecond: point.speed))
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                if point.speed > limit {
                    PointMark(
                        x: .value("Minutes", point.offset / 60),
                        y: .value("Speed", unit.value(fromMetresPerSecond: point.speed))
                    )
                    .foregroundStyle(.red)
                    .symbolSize(18)
                }
            }
            RuleMark(y: .value("Limit", unit.value(fromMetresPerSecond: limit)))
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text("Limit")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
        }
        .chartYScale(domain: 0...(unit.value(fromMetresPerSecond: top) * 1.2))
        .chartXAxisLabel("Minutes")
        .chartYAxisLabel(unit.symbol)
        .frame(height: 200)
    }
}
