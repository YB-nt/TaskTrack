import Foundation
import TaskflowCore

// Lightweight stand-in for a test suite. This environment only has the Command Line
// Tools installed (no full Xcode), and neither XCTest nor swift-testing's runtime
// dylib (Testing.framework) can be located by `swift test` as a result — the compiler
// finds the module but the test bundle fails to dlopen it at runtime. Rather than fight
// the sandboxed toolchain, this is a plain executable that runs the same assertions and
// reports pass/fail with a non-zero exit code, invoked via `swift run TaskflowVerify`.

var failureCount = 0
var checkCount = 0

@MainActor
func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    checkCount += 1
    if !condition() {
        failureCount += 1
        print("FAIL: \(name)")
    }
}

func loadFixture(_ name: String) -> String {
    guard let url = Bundle.module.url(forResource: name, withExtension: "md", subdirectory: "Fixtures") else {
        fatalError("missing fixture \(name).md")
    }
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

// MARK: - WeekWindowParser: Korean-worded "Week 1 = YYYY년 M월 [N]째 주" reference dates

do {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // "2026년 7월 둘째 주" -> the second Monday of July 2026. July 1, 2026 is a Wednesday,
    // so the first Monday is the 6th and the second is the 13th — this is the exact
    // real-world roadmap line that silently disabled all week-relative scheduling (Today,
    // Due Soon, current-week badge, locking) because the parser only understood literal
    // ISO dates ("Week 1 = 2026-07-13") and treated anything else as "unavailable".
    let doc1 = TaskMasterMarkdownParser.parse("Week 1 = 2026년 7월 둘째 주\n\n## Task 1 — X\n```\n# Task ID: 1\n# Title: X\n# Status: pending\n```\n")
    check("Korean week1: '2026년 7월 둘째 주' resolves to 2026-07-13", doc1.week1ReferenceDate == date(2026, 7, 13))

    let doc2 = TaskMasterMarkdownParser.parse("Week 1 = 2026년 1월 첫째 주\n\n## Task 1 — X\n```\n# Task ID: 1\n# Title: X\n# Status: pending\n```\n")
    check("Korean week1: '첫째' (1st) resolves correctly", doc2.week1ReferenceDate == date(2026, 1, 5))

    let docNone = TaskMasterMarkdownParser.parse("이 문서엔 주차 기준선이 없다.\n\n## Task 1 — X\n```\n# Task ID: 1\n# Title: X\n# Status: pending\n```\n")
    check("no week1 line: still degrades to nil, not a crash", docNone.week1ReferenceDate == nil)
}

// MARK: - tasks.md (2-level: Task → Subtask)

do {
    let doc = TaskMasterMarkdownParser.parse(loadFixture("tasks"))

    check("tasks.md: 14 top-level tasks", doc.tasks.count == 14)
    check("tasks.md: projectName parsed", doc.projectName == "tsnlab-sw-application")

    if let task3 = doc.item(withId: "3") {
        check("task 3 dependencies", task3.dependencies == ["1", "2"])
        check("task 3 window start", task3.window?.startWeek == 12)
        check("task 3 window end", task3.window?.endWeek == 18)
        check("task 3 priority", task3.priority == .high)
    } else {
        check("task 3 exists", false)
    }

    if let task14 = doc.item(withId: "14") {
        check("task 14 window start (from Task List table)", task14.window?.startWeek == 17)
    } else {
        check("task 14 exists", false)
    }

    if let task1 = doc.item(withId: "1") {
        check("task 1 subtask ids", task1.children.map(\.id) == ["1.1", "1.2", "1.3", "1.4", "1.5", "1.6"])
        check("task 1 test strategy count", task1.testStrategy.count == 4)
        check("task 1 test strategy first unchecked", task1.testStrategy.first?.checked == false)
    } else {
        check("task 1 exists", false)
    }

    if let subtask12 = doc.item(withId: "1.2") {
        check("subtask 1.2 deps", subtask12.dependencies == ["1.1"])
        check("subtask 1.2 window start", subtask12.window?.startWeek == 5)
        check("subtask 1.2 details non-nil", subtask12.details != nil)
    } else {
        check("subtask 1.2 exists", false)
    }

    var missingDeps: [String] = []
    for item in doc.allItems {
        for dep in item.dependencies where doc.item(withId: dep) == nil {
            missingDeps.append("\(item.id) -> \(dep)")
        }
    }
    check("all dependency ids resolve to real items (\(missingDeps.joined(separator: ", ")))", missingDeps.isEmpty)
}

// MARK: - tasks_v2.md (3-level: Task → Subtask → table row)

do {
    let doc = TaskMasterMarkdownParser.parse(loadFixture("tasks_v2"))

    check("tasks_v2.md: 2 top-level tasks", doc.tasks.count == 2)

    if let subtask11 = doc.item(withId: "1.1") {
        check("subtask 1.1 table-row children", subtask11.children.map(\.id) == ["1.1.1", "1.1.2", "1.1.3", "1.1.4"])
    } else {
        check("subtask 1.1 exists", false)
    }

    if let row112 = doc.item(withId: "1.1.2") {
        check("row 1.1.2 status done", row112.status == .done)
        check("row 1.1.2 statusLocation kind", row112.statusLocation?.kind == .tableRow)
        // Table rows have no week label of their own ("1.1.2" is just an id) — they must
        // inherit the parent subtask's window ("1.1 — Week 4") or every schedule computation
        // that reads a leaf's window (active-now, urgency sort, locking, due-soon) silently
        // no-ops for 3-level documents. This is the exact bug behind "Phase 2 always sorts
        // to the very bottom of the Dashboard" even while it's clearly the active phase.
        check("row 1.1.2 inherits parent subtask's window (Week 4)", row112.window?.startWeek == 4 && row112.window?.endWeek == 4)
    } else {
        check("row 1.1.2 exists", false)
    }

    if let row121 = doc.item(withId: "1.2.1") {
        check("row 1.2.1 inherits parent subtask's window (Week 5, different from 1.1's Week 4)",
              row121.window?.startWeek == 5 && row121.window?.endWeek == 5)
    } else {
        check("row 1.2.1 exists", false)
    }

    // With window inheritance fixed, Task 1 (Phase 2, W4-9) should sort ahead of Task 2
    // (Phase 2.5, W10-11) once we're inside Task 1's window — it's still open work with a
    // week 4-9 window and is now correctly detected as "active now", the opposite of the
    // pre-fix behavior where its table-row leaves all evaluated as un-windowed and it
    // dropped to the bottom by every sort key (isActiveNow, urgencyWeek) falling back.
    var utcCal = Calendar(identifier: .gregorian)
    utcCal.timeZone = TimeZone(identifier: "UTC")!
    let midPhase2 = utcCal.date(from: DateComponents(year: 2026, month: 8, day: 15))!
    let schedule = ScheduleEngine.compute(document: doc, now: midPhase2)
    check("tasks_v2.md: currentWeek lands in week 5", schedule.currentWeek == 5)
    check("tasks_v2.md: Phase 2 (Task 1) sorts before Phase 2.5 (Task 2) while its window is active",
          schedule.phaseTracks.map(\.id) == ["1", "2"])
    check("tasks_v2.md: Phase 2 phaseTrack is flagged active-now",
          schedule.phaseTracks.first { $0.id == "1" }?.isActiveNow == true)

    if let subtask12 = doc.item(withId: "1.2") {
        check("subtask 1.2 status in-progress", subtask12.status == .inProgress)
        check("subtask 1.2 statusLocation kind", subtask12.statusLocation?.kind == .inlineBacktickAfterBold)
    } else {
        check("subtask 1.2 exists", false)
    }

    if let date = doc.week1ReferenceDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        check("week1ReferenceDate year", c.year == 2026)
        check("week1ReferenceDate month", c.month == 7)
        check("week1ReferenceDate day", c.day == 13)
    } else {
        check("week1ReferenceDate parsed", false)
    }
}

// MARK: - GitHubFileFetcher.parse (URL recognition only — no network calls in this suite)

do {
    let blobURL = URL(string: "https://github.com/YB-nt/TaskTrack/blob/develop/reference/tasks.md")!
    let parsed = GitHubFileFetcher.parse(blobURL)
    check("github: blob URL parses owner", parsed?.owner == "YB-nt")
    check("github: blob URL parses repo", parsed?.repo == "TaskTrack")
    check("github: blob URL parses ref (branch)", parsed?.ref == "develop")
    check("github: blob URL parses nested path", parsed?.path == "reference/tasks.md")

    let rawURL = URL(string: "https://raw.githubusercontent.com/YB-nt/TaskTrack/main/README.md")!
    let parsedRaw = GitHubFileFetcher.parse(rawURL)
    check("github: raw URL parses owner/repo/ref/path", parsedRaw == GitHubFileFetcher.Reference(owner: "YB-nt", repo: "TaskTrack", ref: "main", path: "README.md"))

    check("github: non-GitHub host is rejected", GitHubFileFetcher.parse(URL(string: "https://example.com/owner/repo/blob/main/x.md")!) == nil)
    check("github: github.com URL missing /blob/ is rejected", GitHubFileFetcher.parse(URL(string: "https://github.com/YB-nt/TaskTrack")!) == nil)
}

// MARK: - TaskFileWriter (in-place status/checklist edits, round-tripped through the parser)

do {
    let original = loadFixture("tasks_v2")
    let doc = TaskMasterMarkdownParser.parse(original)

    // .tableRow: this is the exact shape that had a real bug — replacingTableCell built the
    // trailing-whitespace padding via `cellText.reversed().prefix(while:).reversed()` without
    // wrapping it back into a String, so the written cell held Swift's debug dump of a
    // ReversedCollection instead of plain spaces. Assert both the round-tripped status *and*
    // that no such debug text leaked into the file.
    if let row112 = doc.item(withId: "1.1.2") {
        check("writer setup: row 1.1.2 starts done", row112.status == .done)
        if let written = TaskFileWriter.settingStatus(.pending, for: row112, in: original) {
            check("writer: no debug-dump leakage in written table row", !written.contains("ReversedCollection"))
            check("writer: line count unchanged (in-place edit only)",
                  written.components(separatedBy: "\n").count == original.components(separatedBy: "\n").count)
            let reparsed = TaskMasterMarkdownParser.parse(written)
            check("writer: row 1.1.2 status round-trips to pending", reparsed.item(withId: "1.1.2")?.status == .pending)
            check("writer: sibling row 1.1.1 untouched", reparsed.item(withId: "1.1.1")?.status == .pending)
        } else {
            check("writer: settingStatus(.tableRow) returned a value", false)
        }
    } else {
        check("writer setup: row 1.1.2 exists", false)
    }

    // .inlineBacktickAfterBold
    if let subtask12 = doc.item(withId: "1.2"), let written = TaskFileWriter.settingStatus(.done, for: subtask12, in: original) {
        let reparsed = TaskMasterMarkdownParser.parse(written)
        check("writer: subtask 1.2 status round-trips to done", reparsed.item(withId: "1.2")?.status == .done)
    } else {
        check("writer: settingStatus(.inlineBacktickAfterBold) returned a value", false)
    }

    // .fencedField (top-level task's own `# Status:` line)
    if let task1 = doc.item(withId: "1"), let written = TaskFileWriter.settingStatus(.done, for: task1, in: original) {
        let reparsed = TaskMasterMarkdownParser.parse(written)
        check("writer: task 1 status round-trips to done", reparsed.item(withId: "1")?.status == .done)
    } else {
        check("writer: settingStatus(.fencedField) returned a value", false)
    }

    // Checklist toggle round-trip.
    let tasksDoc = TaskMasterMarkdownParser.parse(loadFixture("tasks"))
    if let task1 = tasksDoc.item(withId: "1"), let firstCheck = task1.testStrategy.first {
        check("writer setup: checklist item starts unchecked", firstCheck.checked == false)
        let written = TaskFileWriter.togglingChecklistItem(firstCheck, in: loadFixture("tasks"))
        let reparsed = TaskMasterMarkdownParser.parse(written)
        check("writer: checklist item round-trips to checked", reparsed.item(withId: "1")?.testStrategy.first?.checked == true)
    } else {
        check("writer setup: checklist item exists", false)
    }
}

// MARK: - ScheduleEngine (synthetic fixture, fixed dates for determinism)

do {
    let synthetic = """
    **Project**: Synthetic
    Week 1 = 2026-01-05 (Mon)

    ## Task 1 — Phase A

    ```
    # Task ID: 1
    # Title: Phase A
    # Status: pending
    # Dependencies: none
    # Priority: high
    ```

    ### Subtasks

    **1.1 — Week 1: Step one** `done` / deps: none
    - detail one

    **1.2 — Week 2: Step two** `pending` / deps: 1.1
    - detail two

    **1.3 — Week 3: Step three** `pending` / deps: 1.2
    - detail three
    """
    let doc = TaskMasterMarkdownParser.parse(synthetic)
    check("synthetic: week1ReferenceDate parsed", doc.week1ReferenceDate != nil)
    check("synthetic: 3 leaves", doc.tasks.first?.children.count == 3)

    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // now = week 1 (2026-01-10): only 1.1 is done, nothing else has started yet — but the
    // schedule is running ahead (33% actual vs 0% planned), so 1.2 (Week 2, next week) is
    // pulled forward into today's list. 1.3 (Week 3) stays out since it's two weeks out.
    let scheduleWeek1 = ScheduleEngine.compute(document: doc, now: date(2026, 1, 10))
    check("week1: currentWeek == 1", scheduleWeek1.currentWeek == 1)
    check("week1: overall total == 3", scheduleWeek1.overall.total == 3)
    check("week1: overall doneCount == 1", scheduleWeek1.overall.doneCount == 1)
    check("week1: overall pct == 33", scheduleWeek1.overall.pct == 33)
    check("week1: planned pct == 0 (current <= min start)", scheduleWeek1.overallPlannedPct == 0)
    check("week1: delta tone ahead (33% actual vs 0% planned)", scheduleWeek1.overallDelta?.tone == .ahead)
    check("week1: today list pulls forward only 1.2 (next week, since ahead)", scheduleWeek1.todayItems.map(\.id) == ["1.2"])
    check("week1: 1.2 flagged as pulled forward", scheduleWeek1.todayItems.first?.isPulledForwardNextWeek == true)
    check("week1: 1.2 not locked (predecessor 1.1 done)", scheduleWeek1.todayItems.first?.isLocked == false)
    check("week1: today item carries its top-level phaseId (for Dashboard→Curriculum jump)",
          scheduleWeek1.todayItems.first?.phaseId == "1")

    // now = week 3 (2026-01-20): 1.2 and 1.3 have both started; 1.2 unlocks early because
    // its predecessor (1.1) is done, 1.3 stays locked because its predecessor (1.2) isn't.
    let scheduleWeek3 = ScheduleEngine.compute(document: doc, now: date(2026, 1, 20))
    check("week3: currentWeek == 3", scheduleWeek3.currentWeek == 3)
    check("week3: today list has 1.2 and 1.3", Set(scheduleWeek3.todayItems.map(\.id)) == Set(["1.2", "1.3"]))
    check("week3: 1.2 not locked (predecessor 1.1 done)", scheduleWeek3.todayItems.first { $0.id == "1.2" }?.isLocked == false)
    check("week3: due-soon has exactly 1.2 (ends week2, within 3 days of overdue)",
          scheduleWeek3.dueSoonItems.map(\.id) == ["1.2"])
    check("week3: delta tone behind (33% actual vs 100% planned)", scheduleWeek3.overallDelta?.tone == .behind)
    check("week3: nothing flagged as pulled-forward (already behind, not ahead)",
          scheduleWeek3.todayItems.allSatisfy { !$0.isPulledForwardNextWeek })

    // Lock check needs the item to not have already started: use week 1 for this, where
    // 1.3's predecessor section (1.2) is pending (not done) so 1.3 should be locked.
    let phaseTrack = scheduleWeek1.phaseTracks.first
    let chip13 = phaseTrack?.chips.first { $0.id == "1.3" }
    check("week1: chip 1.3 isLocked (predecessor 1.2 pending)", chip13?.isLocked == true)
    let chip12 = phaseTrack?.chips.first { $0.id == "1.2" }
    check("week1: chip 1.2 not locked (predecessor 1.1 done)", chip12?.isLocked == false)
}

// MARK: - ScheduleEngine: pull-forward reaches past an unfinished checkpoint, but doesn't
// leak into unrelated not-yet-started phases (real-world bug: tasks.json said "next: 7-2"
// but 7-2 never showed in Today because it's 2 weeks out and a same-week checkpoint item
// was still pending).

do {
    let synthetic = """
    **Project**: Synthetic
    Week 1 = 2026-01-05 (Mon)

    ## Task 1 — Phase Active (already has done work)

    ```
    # Task ID: 1
    # Title: Phase Active
    # Status: pending
    # Dependencies: none
    # Priority: high
    ```

    ### Subtasks

    **1.1 — Week 2: first section, already worked ahead** `pending` / deps: none
    | ID | Title | Status |
    |---|---|---|
    | 1.1.1 | 문제 1-1 — done problem | done |
    | 1.1.2 | 체크포인트 — still pending, not a 문제 | pending |

    **1.2 — Week 3: second section, the real next problem** `pending` / deps: 1.1
    | ID | Title | Status |
    |---|---|---|
    | 1.2.1 | 문제 2-1 — the real next problem | pending |

    ## Task 2 — Phase Untouched (nothing done yet)

    ```
    # Task ID: 2
    # Title: Phase Untouched
    # Status: pending
    # Dependencies: none
    # Priority: high
    ```

    ### Subtasks

    **2.1 — Week 3: also future, but this whole phase is untouched** `pending` / deps: none
    - detail
    """
    let doc = TaskMasterMarkdownParser.parse(synthetic)
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let now = utc.date(from: DateComponents(year: 2026, month: 1, day: 5))! // week 1 — before either section's window
    let schedule = ScheduleEngine.compute(document: doc, now: now)

    check("checkpoint-skip: currentWeek == 1", schedule.currentWeek == 1)
    check("checkpoint-skip: overall is ahead (already finished a Week-2 problem while still in week 1)", schedule.overallDelta?.tone == .ahead)
    check("checkpoint-skip: 문제 2-1 (Week 3, in the already-active phase) pulls forward despite the Week 2 checkpoint still being open",
          schedule.todayItems.contains { $0.id == "1.2.1" })
    check("checkpoint-skip: the still-open checkpoint itself does NOT show (it's cleared-for-progression, not literally done)",
          !schedule.todayItems.contains { $0.id == "1.1.2" })
    check("checkpoint-skip: Task 2's Week-3 section does NOT pull forward — that whole phase hasn't started",
          !schedule.todayItems.contains { $0.id == "2.1" })
    check("checkpoint-skip: today list is exactly [1.2.1], not flooded with every future section",
          schedule.todayItems.map(\.id) == ["1.2.1"])
}

// MARK: - ScheduleEngine: in-progress table row buried behind a pending sibling still
// surfaces in "Today" (3-level tasks_v2.md shape — a subtask's section can have multiple
// leaves, and only one leaf per section is picked to represent it in Today)

do {
    let synthetic = """
    **Project**: Synthetic
    Week 1 = 2026-01-05 (Mon)

    ## Task 1 — Phase A

    ```
    # Task ID: 1
    # Title: Phase A
    # Status: pending
    # Dependencies: none
    # Priority: high
    ```

    ### Subtasks

    **1.1 — Week 1: Section with a buried in-progress row** `pending` / deps: none

    | ID | Title | Status |
    |---|---|---|
    | 1.1.1 | Row one, still pending | pending |
    | 1.1.2 | Row two, actually in progress | in-progress |
    """
    let doc = TaskMasterMarkdownParser.parse(synthetic)
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let now = utc.date(from: DateComponents(year: 2026, month: 1, day: 10))!
    let schedule = ScheduleEngine.compute(document: doc, now: now)

    check("buried in-progress: row 1.1.2 parsed in-progress", doc.item(withId: "1.1.2")?.status == .inProgress)
    check("buried in-progress: row 1.1.1 parsed pending (document order comes first)",
          doc.item(withId: "1.1.1")?.status == .pending)
    check("buried in-progress: Today represents the section with the in-progress row, not the earlier pending one",
          schedule.todayItems.map(\.id) == ["1.1.2"])
}

// MARK: - ScheduleEngine: in-progress items sort to the top of "Today" (priority runner-up)

do {
    let synthetic = """
    **Project**: Synthetic
    Week 1 = 2026-01-05 (Mon)

    ## Task 1 — Phase A

    ```
    # Task ID: 1
    # Title: Phase A
    # Status: pending
    # Dependencies: none
    # Priority: high
    ```

    ### Subtasks

    **1.1 — Week 1: High priority, not started** `pending` / deps: none
    - detail one

    **1.2 — Week 1: Low priority, already in progress** `in-progress` / deps: none
    - detail two
    """
    let doc = TaskMasterMarkdownParser.parse(synthetic)
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let now = utc.date(from: DateComponents(year: 2026, month: 1, day: 10))!
    let schedule = ScheduleEngine.compute(document: doc, now: now)

    check("in-progress sort: 1.1 parsed high priority", doc.item(withId: "1.1")?.priority == .high)
    check("in-progress sort: 1.2 parsed in-progress, no priority", doc.item(withId: "1.2")?.status == .inProgress)
    check("in-progress sort: both items present in today", Set(schedule.todayItems.map(\.id)) == Set(["1.1", "1.2"]))
    check("in-progress sort: in-progress 1.2 sorts before higher-priority-but-pending 1.1",
          schedule.todayItems.first?.id == "1.2")
}

// MARK: - ProblemDetailParser (하위 파일, e.g. Phase2.md)

do {
    let parsed = ProblemDetailParser.parse(loadFixture("phase_sample"))

    check("phase_sample: 2 problems parsed (checkpoint excluded)", parsed.count == 2)
    check("phase_sample: 6-1 body contains 목표", parsed["6-1"]?.contains("목표") == true)
    check("phase_sample: 6-1 body excludes next heading", parsed["6-1"]?.contains("6-2") == false)
    check("phase_sample: 6-2 body captured", parsed["6-2"]?.contains("파일 오프셋") == true)
    check("phase_sample: checkpoint (no 문제 X-Y id) not captured", parsed["체크포인트"] == nil)

    check("problemId: matches tasks.md-style row title",
          ProblemDetailParser.problemId(in: "문제 6-1 — 파일 복사 두 벌") == "6-1")
    check("problemId: matches 하위 파일 heading",
          ProblemDetailParser.problemId(in: "### 문제 7-2. fork + exec — 미니 프로세스 실행기") == "7-2")
    check("problemId: nil when no 문제 X-Y token",
          ProblemDetailParser.problemId(in: "체크포인트 — fd ↔ 소켓 연결고리") == nil)
}

// MARK: - TaskDocumentStore supplement file merge

do {
    let doc = TaskDocumentStore()
    check("fresh store: no supplement files", doc.supplementFiles.isEmpty)
    check("fresh store: unmatched problem id returns nil", doc.supplementDetail(for: "6-1") == nil)
}

print("\(checkCount - failureCount)/\(checkCount) checks passed")
if failureCount > 0 {
    exit(1)
}
