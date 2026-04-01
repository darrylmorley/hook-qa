import SwiftUI

struct BehaviourTab: View {
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: Presets
                VStack(alignment: .leading, spacing: 6) {
                    Text("Presets")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        PresetButton(label: "Strict") { applyPreset(.strict) }
                        PresetButton(label: "Balanced") { applyPreset(.balanced) }
                        PresetButton(label: "Light") { applyPreset(.light) }
                    }
                }

                Divider()

                // MARK: Block on Warnings
                SettingRow(
                    label: "Block on Warnings",
                    description: "When enabled, warnings (not just criticals) will block Claude from stopping."
                ) {
                    Toggle("", isOn: Binding(
                        get: { settings.config.behaviour.blockOnWarnings },
                        set: { settings.config.behaviour.blockOnWarnings = $0; settings.scheduleSave() }
                    ))
                    .labelsHidden()
                }

                Divider()

                // MARK: Max Diff Lines
                LabeledSliderRow(
                    label: "Max Diff Lines",
                    description: "Maximum diff lines sent to the model. Larger = better context but slower.",
                    value: Binding(
                        get: { Double(settings.config.behaviour.maxDiffLines) },
                        set: { settings.config.behaviour.maxDiffLines = Int($0); settings.scheduleSave() }
                    ),
                    range: 100...2000,
                    step: 100,
                    format: { "\(Int($0))" }
                )

                Divider()

                // MARK: Min Diff Lines
                LabeledSliderRow(
                    label: "Min Diff Lines",
                    description: "Skip QA for trivial changes below this threshold.",
                    value: Binding(
                        get: { Double(settings.config.behaviour.minDiffLines) },
                        set: { settings.config.behaviour.minDiffLines = Int($0); settings.scheduleSave() }
                    ),
                    range: 0...50,
                    step: 5,
                    format: { "\(Int($0))" }
                )

                Divider()

                // MARK: Max Retries
                SettingRow(
                    label: "Max Retries",
                    description: "How many times Claude can retry fixes before the hook lets it stop."
                ) {
                    HStack(spacing: 8) {
                        Text("\(settings.config.behaviour.maxRetries)")
                            .monospacedDigit()
                            .frame(minWidth: 20, alignment: .trailing)
                        Stepper("", value: Binding(
                            get: { settings.config.behaviour.maxRetries },
                            set: { settings.config.behaviour.maxRetries = $0; settings.scheduleSave() }
                        ), in: 1...3)
                        .labelsHidden()
                    }
                }

                Divider()

                // MARK: Timeout
                LabeledSliderRow(
                    label: "Timeout",
                    description: "Max seconds to wait for the model response.",
                    value: Binding(
                        get: { Double(settings.config.connection.timeout) },
                        set: { settings.config.connection.timeout = Int($0); settings.scheduleSave() }
                    ),
                    range: 30...300,
                    step: 10,
                    format: { "\(Int($0))s" }
                )

                Divider()

                // MARK: Temperature
                LabeledSliderRow(
                    label: "Temperature",
                    description: "Lower = more focused reviews. Higher = more varied critiques.",
                    value: Binding(
                        get: { settings.config.behaviour.temperature },
                        set: { settings.config.behaviour.temperature = $0; settings.scheduleSave() }
                    ),
                    range: 0.0...1.0,
                    step: 0.05,
                    format: { String(format: "%.2f", $0) }
                )

                Spacer()
            }
            .padding(12)
        }
    }

    // MARK: - Presets

    private enum Preset {
        case strict, balanced, light
    }

    private func applyPreset(_ preset: Preset) {
        switch preset {
        case .strict:
            settings.config.behaviour.blockOnWarnings = true
            settings.config.behaviour.minDiffLines = 1
            settings.config.behaviour.maxDiffLines = 800
            settings.config.behaviour.temperature = 0.05
            settings.config.review.weights.correctness = 10
            settings.config.review.weights.completeness = 10
            settings.config.review.weights.specAdherence = 8
            settings.config.review.weights.codeQuality = 6
        case .balanced:
            settings.config.behaviour.blockOnWarnings = false
            settings.config.behaviour.minDiffLines = 5
            settings.config.behaviour.maxDiffLines = 500
            settings.config.behaviour.temperature = 0.1
            settings.config.review.weights.correctness = 10
            settings.config.review.weights.completeness = 8
            settings.config.review.weights.specAdherence = 6
            settings.config.review.weights.codeQuality = 4
        case .light:
            settings.config.behaviour.blockOnWarnings = false
            settings.config.behaviour.minDiffLines = 20
            settings.config.behaviour.maxDiffLines = 300
            settings.config.behaviour.temperature = 0.15
            settings.config.review.weights.correctness = 10
            settings.config.review.weights.completeness = 4
            settings.config.review.weights.specAdherence = 2
            settings.config.review.weights.codeQuality = 2
        }
        settings.scheduleSave()
    }
}

// MARK: - Reusable row components

/// A settings row with a label, description, and trailing control.
private struct SettingRow<Control: View>: View {
    let label: String
    let description: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(label)
                    .font(.body)
                Spacer()
                control()
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// A settings row with a label, description, current value badge, and a slider.
private struct LabeledSliderRow: View {
    let label: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(label)
                    .font(.body)
                Spacer()
                Text(format(value))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, alignment: .trailing)
            }
            Slider(value: $value, in: range, step: step)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// A compact preset-style button.
private struct PresetButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

#Preview {
    BehaviourTab()
        .environment(SettingsManager.shared)
        .frame(width: 380, height: 500)
}
