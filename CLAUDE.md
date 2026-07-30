## 하네스: 일정 모니터링 앱 (macOS Swift/SwiftUI)

**목표:** Claude Design(claude.ai)에서 제작한 디자인을 Claude Code export로 반입하여 SwiftUI로 구현하고, 통합 정합성/디자인 충실도를 검증하는 3인 에이전트 팀(design-integrator → swiftui-developer → qa-inspector) 운영.

**트리거:** 디자인 반영, 화면/기능 구현, 빌드, QA 등 이 앱 관련 작업 요청 시 `schedule-monitor-swift-orchestrator` 스킬을 사용하라. 단순 질문은 직접 응답 가능.

**Claude Design export 반입 위치:** `design-exports/` — 사용자가 이 폴더에 export 산출물을 넣으면 다음 실행 때 자동 반영된다.

**현재 상태 (2026-07-30):** `Taskflow` 앱 1차 구현 완료 — Swift Package(`Package.swift`, `swift-tools-version: 6.0`) 형태로 `Sources/TaskflowCore`(파서/스케줄엔진/디자인시스템/스토어, 라이브러리) + `Sources/Taskflow`(SwiftUI 앱, RootView/Dashboard/Curriculum/StepDetail/Sync) + `Sources/TaskflowVerify`(테스트 대체 실행 파일) 구조. `swift build` 통과, `swift run TaskflowVerify` 39/39 통과, `swift run Taskflow`로 앱 실행 확인(크래시 없음, 시각 확인은 미완 — 아래 참조). 상세 설계는 `/Users/yyb/.claude/plans/optimized-stirring-rain.md` 참조 (세션이 달라져도 경로로 직접 Read 가능).

**이 세션에서 확인된 환경 제약 (다음 세션에서 재확인 불필요):**
- `TeamCreate`/공유 작업 목록형 `TaskCreate`(assignee/depends_on)가 이 Claude Code CLI에는 **툴로 존재하지 않음** — `schedule-monitor-swift-orchestrator` 스킬의 "에이전트 팀" 모드는 폴백 지침이 스킬 본문에 추가됨(리더가 직접 3개 역할을 순차 수행).
- `swift test`(XCTest/swift-testing) 불가 — 전체 Xcode 없이 Command Line Tools만 설치됨. `swift run TaskflowVerify`(일반 executable)로 대체. 상세는 `swiftui-app-development`/`swift-integration-qa` 스킬 참조.
- Screen Recording/Accessibility 권한 없음 — 실행 중인 앱의 스크린샷/UI 트리 자동 확인 불가. 시각 검증은 사용자에게 요청해야 함.

**다음 세션에서 이어가려면:** "Taskflow 앱 이어서 개발해줘 — [구체적 요청]" 처럼 도메인 키워드(Taskflow, 일정 모니터링, taskmaster)만 언급하면 `schedule-monitor-swift-orchestrator` 스킬이 트리거되고, 이 CLAUDE.md와 스킬 본문의 폴백 지침을 통해 별도 설명 없이 이어갈 수 있다.

**변경 이력:**
| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-07-30 | 초기 구성 (design-integrator, swiftui-developer, qa-inspector + 오케스트레이터) | 전체 | 일정 모니터링 앱 개발 하네스 신규 구축 — 기능 범위/백엔드 여부는 미정, 하네스부터 우선 구축 |
| 2026-07-30 | Taskflow 앱 1차 구현 (파서/스케줄엔진/디자인시스템/SwiftUI 화면 4개) | Sources/*, Package.swift | Claude Design export("Taskmaster Dashboard") 반영 + taskmaster .md 기반 일정 파악 기능 요청 |
| 2026-07-30 | 오케스트레이터에 TeamCreate 불가 시 폴백 지침 추가 | skills/schedule-monitor-swift-orchestrator | 이 환경에 TeamCreate 툴 자체가 없음을 실행 중 발견 |
| 2026-07-30 | swift test 대신 swift run 기반 검증 가이드 추가 | skills/swiftui-app-development, skills/swift-integration-qa | CLT만 설치된 환경에서 XCTest/swift-testing 런타임 링크 실패 발견 |
