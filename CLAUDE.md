## 하네스: 일정 모니터링 앱 (macOS Swift/SwiftUI)

**목표:** Claude Design(claude.ai)에서 제작한 디자인을 Claude Code export로 반입하여 SwiftUI로 구현하고, 통합 정합성/디자인 충실도를 검증하는 3인 에이전트 팀(design-integrator → swiftui-developer → qa-inspector) 운영.

**트리거:** 디자인 반영, 화면/기능 구현, 빌드, QA 등 이 앱 관련 작업 요청 시 `schedule-monitor-swift-orchestrator` 스킬을 사용하라. 단순 질문은 직접 응답 가능.

**Claude Design export 반입 위치:** `design-exports/` — 사용자가 이 폴더에 export 산출물을 넣으면 다음 실행 때 자동 반영된다.

**현재 상태 (2026-07-31):** `Taskflow` 앱 1차 구현 완료 — Swift Package(`Package.swift`, `swift-tools-version: 6.0`) 형태로 `Sources/TaskflowCore`(파서/스케줄엔진/디자인시스템/스토어, 라이브러리) + `Sources/Taskflow`(SwiftUI 앱, RootView/Dashboard/Curriculum/StepDetail/Sync) + `Sources/TaskflowVerify`(테스트 대체 실행 파일) 구조. `swift build` 통과, `swift run TaskflowVerify` 49/49 통과. **시각 확인**: Dashboard 화면만 캡처 확인됨(Curriculum/Sync 탭은 미확인, `_workspace_20260730_2119/03_qa/qa_report_1.md` 참조). 상세 설계는 `/Users/yyb/.claude/plans/optimized-stirring-rain.md` 참조 (세션이 달라져도 경로로 직접 Read 가능).

**추가 구현됨 — Phase2.md류 하위 파일 자동 교차연결 (계획서 원안엔 "범위 밖"이었으나 실제 구현됨, 2026-07-31 확인):** `ProblemDetailParser`가 하위 파일(`### 문제 X-Y. ...`)을 파싱해 `tasks.md`/`tasks_v2.md` 행 제목의 동일 `문제 X-Y` 토큰과 매칭. `TaskDocumentStore`에 `supplementFiles`/`addSupplementFile`/`supplementDetail(for:)` 추가, Sync 탭에 "하위 파일" 카드, Step Detail에 "실행 문서 (하위 파일)" 섹션 추가. `MarkdownBlockView` 신규(코드펜스/불릿 목록 렌더링, 기존 Description/Details도 이걸로 교체됨). 빌드/유닛테스트/View↔Store 경계면 QA 통과 — 실제 앱 시각 확인은 아직 안 함, 아직 커밋되지 않은 워킹트리 상태. 상세는 `_workspace/` 참조.

**이 세션에서 확인된 환경 제약 (다음 세션에서 재확인 불필요):**
- `TeamCreate`/공유 작업 목록형 `TaskCreate`(assignee/depends_on)가 이 Claude Code CLI에는 **툴로 존재하지 않음** — `schedule-monitor-swift-orchestrator` 스킬의 "에이전트 팀" 모드는 폴백 지침이 스킬 본문에 추가됨(리더가 직접 3개 역할을 순차 수행).
- `swift test`(XCTest/swift-testing) 불가 — 전체 Xcode 없이 Command Line Tools만 설치됨. `swift run TaskflowVerify`(일반 executable)로 대체. 상세는 `swiftui-app-development`/`swift-integration-qa` 스킬 참조.
- Screen Recording/Accessibility 권한: **2026-07-30에 해결됨.** Accessibility는 원래 정상 동작(`osascript`+System Events 확인). Screen Recording은 `tccutil reset ScreenCapture com.googlecode.iterm2` 후 iTerm2 재시작으로 재부여, TCC 로그(authValue=2 ALLOWED)와 실제 캡처로 검증 완료. `screencapture`가 단색 이미지를 반환하면 권한이 아니라 디스플레이 절전 상태일 수 있으니 `caffeinate -u -t 3`로 화면을 깨운 뒤 재시도할 것.
- `swift run Taskflow`로 뜬 창이 안 보임(backgroundOnly): Info.plist 없는 번들 없는 실행 파일은 macOS가 backgroundOnly로 취급해 창을 생성하지 않음(`System Events`로 `background only of process`가 true, `windowCount:0`). `Sources/Taskflow/TaskflowApp.swift`에 `NSApplicationDelegateAdaptor` + `NSApp.setActivationPolicy(.regular)`/`NSApp.activate(ignoringOtherApps: true)`로 해결 완료 — 이미 소스에 반영되어 있으니 재작업 불필요.

**다음 세션에서 이어가려면:** "Taskflow 앱 이어서 개발해줘 — [구체적 요청]" 처럼 도메인 키워드(Taskflow, 일정 모니터링, taskmaster)만 언급하면 `schedule-monitor-swift-orchestrator` 스킬이 트리거되고, 이 CLAUDE.md와 스킬 본문의 폴백 지침을 통해 별도 설명 없이 이어갈 수 있다.

**변경 이력:**
| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-07-30 | 초기 구성 (design-integrator, swiftui-developer, qa-inspector + 오케스트레이터) | 전체 | 일정 모니터링 앱 개발 하네스 신규 구축 — 기능 범위/백엔드 여부는 미정, 하네스부터 우선 구축 |
| 2026-07-30 | Taskflow 앱 1차 구현 (파서/스케줄엔진/디자인시스템/SwiftUI 화면 4개) | Sources/*, Package.swift | Claude Design export("Taskmaster Dashboard") 반영 + taskmaster .md 기반 일정 파악 기능 요청 |
| 2026-07-30 | 오케스트레이터에 TeamCreate 불가 시 폴백 지침 추가 | skills/schedule-monitor-swift-orchestrator | 이 환경에 TeamCreate 툴 자체가 없음을 실행 중 발견 |
| 2026-07-30 | swift test 대신 swift run 기반 검증 가이드 추가 | skills/swiftui-app-development, skills/swift-integration-qa | CLT만 설치된 환경에서 XCTest/swift-testing 런타임 링크 실패 발견 |
| 2026-07-30 | Screen Recording 권한 재부여 + TaskflowApp.swift에 activation policy 수정, Dashboard 화면 실제 캡처로 1차 시각 확인 완료 | Sources/Taskflow/TaskflowApp.swift, CLAUDE.md | 사용자 요청으로 시각 확인 진행 중 backgroundOnly로 창이 안 뜨는 문제 발견 및 해결 |
| 2026-07-31 | Phase2.md류 하위 파일 자동 교차연결 구현을 발견 및 문서화 (소스는 이미 구현되어 있었으나 CLAUDE.md/workspace에 미기록 상태였음) — 빌드/49개 유닛테스트/View↔Store 경계면 QA 통과 확인, 아직 미커밋 | ProblemDetailParser.swift, MarkdownBlockView.swift, TaskDocumentStore.swift, StepDetailView.swift, SyncView.swift, CLAUDE.md, plans/optimized-stirring-rain.md | "이전 작업 이어서 진행해줘" 요청 시 workspace 기록과 실제 git diff가 불일치함을 발견 — 정체를 파악하고 검증/문서화로 마무리 |
