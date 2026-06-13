import Foundation

enum UsagePaths {
    static let appSupportDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/ClaudeMenubar", isDirectory: true)

    static let usageFileURL: URL = appSupportDirectory
        .appendingPathComponent("usage.json")

    static let legacyUsageFileURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/ClaudeUsageLimits/usage.json")

    static let bridgeScriptURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/claude-menubar-bridge.sh")

    static let originalStatusLineCommandURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/claude-menubar-original-command.txt")

    static let legacyBridgeScriptURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/claude-usage-limit-bridge.sh")

    static let legacyOriginalStatusLineCommandURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/claude-usage-limit-original-command.txt")

    static let claudeSettingsURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")
}
