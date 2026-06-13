import Combine
import Darwin
import Foundation

final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageLimitSnapshot?
    @Published private(set) var displayedWeekly: UsageLimitSnapshot.UsageWindow?
    @Published private(set) var weeklyDisplayUpdatedDate: Date?
    @Published private(set) var now = Date()

    private let decoder = JSONDecoder()
    private var source: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: CInt = -1
    private var clockTimer: Timer?

    var hasUsage: Bool {
        snapshot?.currentSession.effectivePercentage(now: now) != nil
            || displayedWeekly?.effectivePercentage(now: now) != nil
            || snapshot?.weekly.effectivePercentage(now: now) != nil
    }

    var weeklyForDisplay: UsageLimitSnapshot.UsageWindow? {
        displayedWeekly ?? snapshot?.weekly
    }

    func start() {
        do {
            try FileManager.default.createDirectory(
                at: UsagePaths.appSupportDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            NSLog("claude-menubar could not create support directory: \(error.localizedDescription)")
        }

        load()
        startMonitoringDirectory()
        startClock()
    }

    func stop() {
        source?.cancel()
        source = nil
        clockTimer?.invalidate()
        clockTimer = nil
    }

    func refreshClock() {
        now = Date()
    }

    func refreshWeeklyDisplay() {
        guard let snapshot else { return }
        displayedWeekly = snapshot.weekly
        weeklyDisplayUpdatedDate = snapshot.updatedDate
    }

    func load() {
        now = Date()
        do {
            let data = try Data(contentsOf: readableUsageFileURL())
            let nextSnapshot = try decoder.decode(UsageLimitSnapshot.self, from: data)
            snapshot = nextSnapshot

            if displayedWeekly == nil {
                displayedWeekly = nextSnapshot.weekly
                weeklyDisplayUpdatedDate = nextSnapshot.updatedDate
            }
        } catch {
            NSLog("claude-menubar failed to load usage data: \(error.localizedDescription)")
            snapshot = nil
        }
    }

    private func readableUsageFileURL() -> URL {
        if FileManager.default.fileExists(atPath: UsagePaths.usageFileURL.path) {
            return UsagePaths.usageFileURL
        }
        return UsagePaths.legacyUsageFileURL
    }

    private func startMonitoringDirectory() {
        guard source == nil else { return }

        directoryFileDescriptor = open(UsagePaths.appSupportDirectory.path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.load()
            }
        }

        let fd = directoryFileDescriptor
        source.setCancelHandler {
            if fd >= 0 {
                close(fd)
            }
        }

        source.resume()
        self.source = source
    }

    private func startClock() {
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshClock()
        }
    }

}
