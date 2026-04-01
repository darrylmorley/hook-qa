import SwiftUI

struct StatusBarView: View {
    @Environment(SettingsManager.self) private var settings

    let connectionStatus: ConnectionStatus

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            // Current model name in monospaced font
            Text(settings.config.connection.model)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)

            Spacer()

            // Master enable/disable toggle
            Toggle("", isOn: Binding(
                get: { settings.config.behaviour.enabled },
                set: { newValue in
                    settings.config.behaviour.enabled = newValue
                    settings.scheduleSave()
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var dotColor: Color {
        switch connectionStatus {
        case .connected:    return .green
        case .unreachable:  return .red
        case .checking:     return .yellow
        }
    }
}

#Preview {
    let settings = SettingsManager.shared
    return StatusBarView(connectionStatus: .connected(5))
        .environment(settings)
        .frame(width: 380)
}
