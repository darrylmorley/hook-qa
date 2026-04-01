import SwiftUI
import AppKit

struct LogsTab: View {
    @Environment(LogWatcher.self) private var logWatcher
    @State private var showClearConfirmation = false
    @State private var expandedIDs: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            if logWatcher.entries.isEmpty {
                emptyState
            } else {
                logList
            }

            Divider()
            footer
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No QA evaluations yet. Logs will appear here after your first hook run.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Log list

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(logWatcher.entries) { entry in
                    LogEntryRow(
                        entry: entry,
                        isExpanded: expandedIDs.contains(entry.id)
                    ) {
                        toggleExpanded(entry.id)
                    }
                    Divider()
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Clear Logs") {
                showClearConfirmation = true
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .confirmationDialog(
                "Clear all log entries?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Logs", role: .destructive) {
                    logWatcher.clearLog()
                    expandedIDs = []
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the log file contents.")
            }

            Spacer()

            Button("Open in Finder") {
                openInFinder()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func toggleExpanded(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    private func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([logWatcher.logFileURL])
    }
}

// MARK: - LogEntryRow

private struct LogEntryRow: View {
    let entry: HookQALogEntry
    let isExpanded: Bool
    let onTap: () -> Void

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                // Main row
                HStack(spacing: 8) {
                    VerdictBadge(verdict: entry.verdict)

                    Text(entry.project)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    Text(Self.relativeDateFormatter.localizedString(for: entry.timestamp, relativeTo: Date()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Secondary info
                HStack(spacing: 8) {
                    Text("\(entry.findings) finding\(entry.findings == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(durationString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Expanded detail
                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        Divider()
                            .padding(.vertical, 2)

                        // Model name in monospaced
                        HStack(spacing: 4) {
                            Text("Model:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.model)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                        }

                        // Summary
                        Text(entry.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Breakdown
                        Text("\(entry.criticals) critical, \(entry.warnings) warning\(entry.warnings == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var durationString: String {
        let seconds = Double(entry.durationMs) / 1000.0
        return String(format: "%.1fs", seconds)
    }
}

// MARK: - VerdictBadge

private struct VerdictBadge: View {
    let verdict: Verdict

    var body: some View {
        Text(verdict.rawValue)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var backgroundColor: Color {
        switch verdict {
        case .pass:    return .green
        case .fail:    return .red
        case .error:   return .gray
        case .skipped: return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    LogsTab()
        .environment(LogWatcher())
        .frame(width: 380, height: 400)
}
