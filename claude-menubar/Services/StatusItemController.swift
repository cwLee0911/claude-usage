import AppKit
import Combine
import SwiftUI

final class StatusItemController: NSObject, NSPopoverDelegate {
    private let store: UsageStore
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    init(store: UsageStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        configurePopover()
        bindStore()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        updateStatusTitle("--%")
        button.font = Self.menuBarTitleFont
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.toolTip = "Claude 사용량"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(
            width: UsagePanelView.panelSize.width,
            height: UsagePanelView.panelSize.height
        )
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: UsagePanelView(store: store) {
                NSApplication.shared.terminate(nil)
            }
        )
    }

    private func bindStore() {
        store.$snapshot.combineLatest(store.$now)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot, now in
                self?.updateStatusTitle(snapshot?.menuBarTitle(now: now) ?? "--%")
            }
            .store(in: &cancellables)
    }

    private func updateStatusTitle(_ title: String) {
        statusItem.button?.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: Self.menuBarTitleFont,
                .foregroundColor: Self.claudeGreen
            ]
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            store.refreshClock()
            store.refreshWeeklyDisplay()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private static let menuBarTitleFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize,
        weight: .semibold
    )

    private static let claudeGreen = NSColor(
        srgbRed: 0.22,
        green: 1.00,
        blue: 0.08,
        alpha: 1
    )
}
