import AppKit
import NetlifyPortfolioSentinelCore
import SwiftUI

@MainActor
final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store = MonitorStore()
    private var observation: NSKeyValueObservation?

    init() {
        configureStatusItem()
        configurePopover()
        store.refresh()
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItem()
            }
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "Netlify Sentinel")
        button.image?.isTemplate = true
        button.title = " NF"
        updateStatusItem()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 430, height: 640)
        popover.contentViewController = NSHostingController(rootView: DashboardView(store: store))
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            updateStatusItem()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        if let snapshot = store.snapshot {
            let marker: String
            switch snapshot.highestRisk {
            case .critical: marker = "!"
            case .high: marker = "^"
            case .watch: marker = "~"
            case .low: marker = ""
            }
            button.title = " NF \(snapshot.totalSites) \(marker)"
        } else {
            button.title = " NF"
        }
    }
}
