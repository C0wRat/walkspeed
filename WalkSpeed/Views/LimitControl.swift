import SwiftUI
import WalkSpeedCore

/// Shows the speed limit with buttons that lower and raise it.
struct LimitControl: View {
    @Binding var limit: Double
    var unit: SpeedUnit

    var body: some View {
        HStack(spacing: 12) {
            stepButton("Lower limit", systemImage: "minus", steps: -1)
            VStack(spacing: 2) {
                Text("Speed limit")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(unit.formatted(limit))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: limit))
                    Text(unit.symbol)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Speed limit")
            .accessibilityValue("\(unit.formatted(limit)) \(unit.symbol)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: step(by: 1)
                case .decrement: step(by: -1)
                @unknown default: break
                }
            }
            stepButton("Raise limit", systemImage: "plus", steps: 1)
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 28))
        .sensoryFeedback(.selection, trigger: limit)
    }

    private func stepButton(_ title: LocalizedStringKey, systemImage: String, steps: Int) -> some View {
        Button {
            step(by: steps)
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .buttonRepeatBehavior(.enabled)
        .disabled(abs(unit.steppedLimit(limit, by: steps) - limit) < 1e-9)
        .accessibilityLabel(title)
    }

    private func step(by steps: Int) {
        withAnimation(.snappy) {
            limit = unit.steppedLimit(limit, by: steps)
        }
    }
}

#Preview {
    @Previewable @State var limit = 1.5
    LimitControl(limit: $limit, unit: .kilometresPerHour)
        .padding()
}
