import SwiftUI
import AppKit

@main
struct HookQAApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // We use AppDelegate for the status item — no window scenes needed.
        Settings {
            EmptyView()
        }
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "checkmark.shield",
            accessibilityDescription: "HookQA"
        )
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 380, height: 520)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environment(SettingsManager.shared)
        )
        popover = pop
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let pop = popover else { return }
        if pop.isShown {
            pop.performClose(nil)
        } else {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }
}
