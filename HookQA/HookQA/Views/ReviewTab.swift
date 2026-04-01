import SwiftUI

struct ReviewTab: View {
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: Weights
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review Weights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                WeightSliderRow(
                    label: "Correctness",
                    description: "Bugs, logic errors, unhandled edge cases, broken control flow.",
                    value: Binding(
                        get: { Double(settings.config.review.weights.correctness) },
                        set: { settings.config.review.weights.correctness = Int($0); settings.scheduleSave() }
                    )
                )

                Divider()

                WeightSliderRow(
                    label: "Completeness",
                    description: "Stubs, TODOs, placeholder implementations, half-finished features.",
                    value: Binding(
                        get: { Double(settings.config.review.weights.completeness) },
                        set: { settings.config.review.weights.completeness = Int($0); settings.scheduleSave() }
                    )
                )

                Divider()

                WeightSliderRow(
                    label: "Spec Adherence",
                    description: "Does the code match what CLAUDE.md describes?",
                    value: Binding(
                        get: { Double(settings.config.review.weights.specAdherence) },
                        set: { settings.config.review.weights.specAdherence = Int($0); settings.scheduleSave() }
                    )
                )

                Divider()

                WeightSliderRow(
                    label: "Code Quality",
                    description: "Code smells, deeply nested logic, duplicated code, missing error handling.",
                    value: Binding(
                        get: { Double(settings.config.review.weights.codeQuality) },
                        set: { settings.config.review.weights.codeQuality = Int($0); settings.scheduleSave() }
                    )
                )

                Divider()

                // MARK: Custom Instructions
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Instructions")
                        .font(.body)

                    TextEditor(text: Binding(
                        get: { settings.config.review.customInstructions },
                        set: { settings.config.review.customInstructions = $0; settings.scheduleSave() }
                    ))
                    .font(.system(.body))
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        // Placeholder text when empty
                        if settings.config.review.customInstructions.isEmpty {
                            Text("Optional: extra instructions appended to the QA prompt. E.g. 'This project uses Bun — flag any Node-specific APIs.'")
                                .font(.system(.body))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }

                    Text("Appended verbatim to the review prompt for every run.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
        }
    }
}

// MARK: - WeightSliderRow

private struct WeightSliderRow: View {
    let label: String
    let description: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(label)
                    .font(.body)
                Spacer()
                Text("\(Int(value))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .trailing)
            }
            Slider(value: $value, in: 0...10, step: 1)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ReviewTab()
        .environment(SettingsManager.shared)
        .frame(width: 380, height: 500)
}
