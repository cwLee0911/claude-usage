import AppKit
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let usageStore = UsageStore()
    private var statusItemController: StatusItemController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            try ClaudeStatusLineInstaller.installIfNeeded()
        } catch {
            NSLog("claude-usage bridge install failed: \(error.localizedDescription)")
        }
        usageStore.start()
        statusItemController = StatusItemController(store: usageStore)
    }
    func applicationWillTerminate(_ notification: Notification) {
        usageStore.stop()
    }
}
