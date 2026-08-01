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

/// A registered "하위 파일" (e.g. `Phase2.md`) — a per-phase write-up of individual
/// problems, kept separate from `tasks.md` and merged in by `문제 X-Y` id.
public struct SupplementFile: Identifiable, Equatable {
    public var id: String { url.path }
    public var url: URL
    public var problemCount: Int
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
    public private(set) var supplementFiles: [SupplementFile] = []
    private var problemDetails: [String: String] = [:]

    public var syncFrequency: SyncFrequency = .manual {
        didSet { reconfigureAutoSync() }
    }

    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var hourlyTimer: Timer?
    /// Hash of the last text *we* wrote — lets the file watcher ignore our own writes
    /// instead of re-diffing a change we already know about (and re-triggering itself).
    private var lastWrittenHash: Int?

    private static let filePathDefaultsKey = "TaskflowSourceFilePath"
    private static let supplementPathsDefaultsKey = "TaskflowSupplementFilePaths"

    public init() {
        if let savedPath = UserDefaults.standard.string(forKey: Self.filePathDefaultsKey) {
            let url = URL(fileURLWithPath: savedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                fileURL = url
                sync()
                reconfigureAutoSync()
            }
        }
        let savedSupplementPaths = UserDefaults.standard.stringArray(forKey: Self.supplementPathsDefaultsKey) ?? []
        for path in savedSupplementPaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                loadSupplementFile(url: url, persist: false)
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

    /// Lets a view surface a validation error (e.g. an unparseable URL string) that never
    /// made it far enough to go through `importSourceFile`/`importSupplementFile` themselves.
    public func reportError(_ message: String) {
        lastError = message
    }

    // MARK: - GitHub import (alternative to manually picking a downloaded file)

    /// Fetches `githubURL` (a `github.com/.../blob/...` or `raw.githubusercontent.com` link)
    /// and adopts the result as the main source file — same as `chooseFile`, just fetched
    /// instead of hand-picked. The fetched text is cached to a plain local file first, so the
    /// source of truth stays "a `.md` file on disk" and Mark Complete/checklist edits keep
    /// working exactly the same way (they just don't push back to GitHub).
    public func importSourceFile(fromGitHub githubURL: URL, token: String?) async {
        await importGitHubFile(githubURL, token: token, onSuccess: chooseFile(url:))
    }

    /// Same as `importSourceFile(fromGitHub:token:)` but registers the result as a 하위 파일
    /// (e.g. a `Phase2.md`) instead of the main source.
    public func importSupplementFile(fromGitHub githubURL: URL, token: String?) async {
        await importGitHubFile(githubURL, token: token, onSuccess: addSupplementFile(url:))
    }

    private func importGitHubFile(_ githubURL: URL, token: String?, onSuccess: (URL) -> Void) async {
        guard let reference = GitHubFileFetcher.parse(githubURL) else {
            lastError = GitHubFileFetcher.FetchError.invalidURL.localizedDescription
            return
        }
        do {
            let text = try await GitHubFileFetcher.fetchContent(reference, token: token)
            let localURL = try Self.cacheGitHubFile(text: text, reference: reference)
            lastError = nil
            onSuccess(localURL)
        } catch {
            lastError = "GitHub에서 가져오지 못했습니다: \(error.localizedDescription)"
        }
    }

    private static func cacheGitHubFile(text: String, reference: GitHubFileFetcher.Reference) throws -> URL {
        let cacheDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Taskflow/GitHubImports/\(reference.owner)/\(reference.repo)", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let filename = (reference.path as NSString).lastPathComponent
        let localURL = cacheDir.appendingPathComponent(filename)
        try text.write(to: localURL, atomically: true, encoding: .utf8)
        return localURL
    }

    // MARK: - Supplement files (per-phase problem write-ups, e.g. `Phase2.md`)

    public func addSupplementFile(url: URL) {
        loadSupplementFile(url: url, persist: true)
    }

    public func removeSupplementFile(_ file: SupplementFile) {
        supplementFiles.removeAll { $0.id == file.id }
        rebuildProblemDetails()
        var paths = UserDefaults.standard.stringArray(forKey: Self.supplementPathsDefaultsKey) ?? []
        paths.removeAll { $0 == file.url.path }
        UserDefaults.standard.set(paths, forKey: Self.supplementPathsDefaultsKey)
    }

    /// The long-form write-up for a `문제 X-Y` id, merged across every registered
    /// supplement file (later registrations win on a duplicate id).
    public func supplementDetail(for problemId: String) -> String? {
        problemDetails[problemId]
    }

    private func loadSupplementFile(url: URL, persist: Bool) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            lastError = "하위 파일을 읽을 수 없습니다: \(url.lastPathComponent)"
            return
        }
        let parsed = ProblemDetailParser.parse(text)
        for (id, body) in parsed { problemDetails[id] = body }
        if let idx = supplementFiles.firstIndex(where: { $0.url == url }) {
            supplementFiles[idx] = SupplementFile(url: url, problemCount: parsed.count)
        } else {
            supplementFiles.append(SupplementFile(url: url, problemCount: parsed.count))
        }
        if persist {
            var paths = UserDefaults.standard.stringArray(forKey: Self.supplementPathsDefaultsKey) ?? []
            if !paths.contains(url.path) { paths.append(url.path) }
            UserDefaults.standard.set(paths, forKey: Self.supplementPathsDefaultsKey)
        }
    }

    private func rebuildProblemDetails() {
        problemDetails = [:]
        for file in supplementFiles {
            guard let text = try? String(contentsOf: file.url, encoding: .utf8) else { continue }
            for (id, body) in ProblemDetailParser.parse(text) { problemDetails[id] = body }
        }
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
