import Foundation
import Observation

public enum SyncFrequency: String, CaseIterable, Codable {
    case manual
    case hourly
    case realtime

    public var label: String {
        switch self {
        case .manual: return "Manual"
        case .hourly: return "Hourly"
        case .realtime: return "Real-time"
        }
    }

    public var detail: String {
        switch self {
        case .manual: return "Sync tasks.md manually whenever it changes."
        case .hourly: return "Taskflow checks tasks.md for changes every hour."
        case .realtime: return "A file watcher syncs the moment tasks.md is saved."
        }
    }
}

public struct ChangeLogEntry: Identifiable, Equatable {
    public var id = UUID()
    public var text: String
    public var date: Date
}

/// Owns the single source-of-truth `.md` file: loads it, watches it (per `syncFrequency`),
/// diffs re-syncs into a change log, and routes every user-initiated mutation (status
/// change, checklist toggle, detail note) through `TaskFileWriter` so the file itself stays
/// the only place task state lives.
@Observable
@MainActor
public final class TaskDocumentStore {
    public private(set) var document: TaskDocument?
    public private(set) var fileURL: URL?
    public private(set) var lastSyncedAt: Date?
    public private(set) var changeLog: [ChangeLogEntry] = []
    public private(set) var lastError: String?

    public var syncFrequency: SyncFrequency = .manual {
        didSet { reconfigureAutoSync() }
    }

    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var hourlyTimer: Timer?
    /// Hash of the last text *we* wrote — lets the file watcher ignore our own writes
    /// instead of re-diffing a change we already know about (and re-triggering itself).
    private var lastWrittenHash: Int?

    private static let filePathDefaultsKey = "TaskflowSourceFilePath"

    public init() {
        if let savedPath = UserDefaults.standard.string(forKey: Self.filePathDefaultsKey) {
            let url = URL(fileURLWithPath: savedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                fileURL = url
                sync()
                reconfigureAutoSync()
            }
        }
    }

    // MARK: - File selection

    public func chooseFile(url: URL) {
        stopWatching()
        fileURL = url
        UserDefaults.standard.set(url.path, forKey: Self.filePathDefaultsKey)
        changeLog = []
        document = nil
        sync()
        reconfigureAutoSync()
    }

    // MARK: - Sync

    @discardableResult
    public func sync() -> Bool {
        guard let fileURL else { return false }
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            lastError = "파일을 읽을 수 없습니다: \(fileURL.lastPathComponent)"
            return false
        }
        if text.hashValue == lastWrittenHash {
            // This is our own write coming back through the file watcher; already reflected.
            lastWrittenHash = nil
            return true
        }
        let newDocument = TaskMasterMarkdownParser.parse(text)
        if let previous = document {
            changeLog.insert(contentsOf: Self.diff(previous, newDocument), at: 0)
        }
        document = newDocument
        lastSyncedAt = Date()
        lastError = nil
        return true
    }

    // MARK: - Mutations (write-back to the source file, then re-sync)

    public func setStatus(_ status: TaskStatus, for item: TaskItem) {
        write { TaskFileWriter.settingStatus(status, for: item, in: $0) }
    }

    public func toggleChecklistItem(_ checklistItem: ChecklistItem) {
        write { TaskFileWriter.togglingChecklistItem(checklistItem, in: $0) }
    }

    public func appendDetailNote(_ note: String, to item: TaskItem) {
        write { TaskFileWriter.appendingDetailNote(note, to: item, in: $0) }
    }

    private func write(_ transform: (String) -> String?) {
        guard let fileURL, let document else { return }
        guard let newText = transform(document.rawText) else { return }
        do {
            try newText.write(to: fileURL, atomically: true, encoding: .utf8)
            lastWrittenHash = newText.hashValue
            sync()
        } catch {
            lastError = "파일에 쓸 수 없습니다: \(error.localizedDescription)"
        }
    }

    // MARK: - Auto sync

    private func reconfigureAutoSync() {
        stopWatching()
        guard let fileURL else { return }
        switch syncFrequency {
        case .manual:
            break
        case .hourly:
            hourlyTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.sync() }
            }
        case .realtime:
            startWatching(fileURL)
        }
    }

    private func startWatching(_ url: URL) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.sync() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        fileMonitorSource = source
    }

    private func stopWatching() {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
        hourlyTimer?.invalidate()
        hourlyTimer = nil
    }

    // MARK: - Change log diffing

    private static func diff(_ old: TaskDocument, _ new: TaskDocument) -> [ChangeLogEntry] {
        var entries: [ChangeLogEntry] = []
        let oldById = Dictionary(uniqueKeysWithValues: old.allItems.map { ($0.id, $0) })
        let newById = Dictionary(uniqueKeysWithValues: new.allItems.map { ($0.id, $0) })
        let now = Date()

        for (id, newItem) in newById.sorted(by: { $0.key < $1.key }) {
            if let oldItem = oldById[id] {
                if oldItem.status != newItem.status {
                    entries.append(ChangeLogEntry(
                        text: "\(id) \(newItem.title): \(oldItem.status.displayLabel) → \(newItem.status.displayLabel)",
                        date: now
                    ))
                }
            } else {
                entries.append(ChangeLogEntry(text: "신규: \(id) \(newItem.title)", date: now))
            }
        }
        for id in oldById.keys where newById[id] == nil {
            entries.append(ChangeLogEntry(text: "삭제됨: \(id) \(oldById[id]?.title ?? id)", date: now))
        }
        return entries
    }
}
