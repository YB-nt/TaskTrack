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
    } else {
        check("row 1.1.2 exists", false)
    }

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
