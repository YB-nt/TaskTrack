---
name: swiftui-app-development
description: "macOS SwiftUI 앱의 MVVM 구조, 상태 관리, 일정/이벤트 모니터링 로직(주기적 체크, 알림), Xcode 빌드/실행을 다루는 개발 스킬. SwiftUI 뷰/뷰모델 작성, '화면 구현해줘', 'SwiftUI 코드 작성해줘', '알림 기능 추가해줘', '빌드해줘' 요청 시 사용."
---

# SwiftUI App Development — 일정 모니터링 앱 구현

macOS 네이티브 일정 모니터링 앱을 SwiftUI로 구현할 때의 구조와 패턴을 정의한다. 기능 범위(외부 캘린더 연동 여부, 서버 유무)는 아직 확정되지 않았으므로, 이 스킬은 범위가 좁혀지기 전에도 유효한 구조적 원칙에 집중한다.

## 프로젝트 구조

```
{AppName}/
├── {AppName}App.swift          # @main 진입점
├── Models/                     # 순수 데이터 모델 (일정, 이벤트, 알림 규칙 등)
├── ViewModels/                 # @Observable 또는 ObservableObject
├── Views/                      # SwiftUI View — 화면/컴포넌트 단위로 분리
├── Services/                   # 모니터링, 알림, (추후) 외부 캘린더 연동 등 비-View 로직
└── DesignTokens.swift          # design-integrator 산출물에서 반입
```

design-integrator가 `_workspace/01_design_spec/`에 만든 `DesignTokens.swift`를 이 위치로 옮기거나 참조한다.

## 상태 관리

- macOS 14+ 타겟이면 `@Observable` 매크로(Observation 프레임워크)를 우선한다 — `ObservableObject` + `@Published`보다 보일러플레이트가 적다.
- 더 낮은 배포 타겟을 지원해야 하면 `ObservableObject` + `@Published`를 사용한다.
- View는 ViewModel의 프로퍼티/메서드만 참조하고, 비즈니스 로직(모니터링 판정, 알림 트리거 조건)을 View 안에 두지 않는다 — qa-inspector가 View↔ViewModel 경계면을 검증하므로, 로직이 섞여 있으면 그 경계 자체가 흐려진다.

## 일정 모니터링 로직

기능 범위가 확정되기 전에도 아래 표준 API들이 대부분의 시나리오를 커버한다. 커스텀 폴링/스케줄링 메커니즘을 새로 만들기 전에 먼저 검토한다.

| 요구사항 | 표준 API |
|---------|---------|
| 주기적으로 일정 상태를 체크 | `Timer.scheduledTimer` 또는 `DispatchSourceTimer` (백그라운드 큐에서 실행 시) |
| 사용자에게 알림 표시 | `UNUserNotificationCenter` — `Info.plist`에 알림 권한 설명 필요, 앱 시작 시 `requestAuthorization` |
| 외부 캘린더(Google/시스템 캘린더) 연동 | `EventKit` — 연동이 실제로 결정된 시점에 도입, 미리 만들지 않는다 |
| 메뉴바 상주형 앱 | `NSStatusItem` (AppKit) — SwiftUI의 `MenuBarExtra`(macOS 13+)가 더 간단하면 우선 검토 |

## 빌드 확인

프로젝트 구조에 따라 다음 중 맞는 방법을 사용한다:

```bash
# Xcode 프로젝트인 경우 — 스킴 목록 확인 후
xcodebuild -list
xcodebuild -scheme <SchemeName> -destination 'platform=macOS' build

# Swift Package인 경우
swift build
```

빌드 에러는 로그 전체를 읽고 근본 원인을 수정한다 — 경고를 무시하고 넘어가지 않는다 (특히 옵셔널 강제 언래핑, 타입 불일치 경고는 런타임 크래시로 이어지기 쉽다).

**이 환경(Command Line Tools만 설치, 전체 Xcode 없음)에서는 `swift test`가 동작하지 않는다** — XCTest도 swift-testing의 `Testing.framework`도 CLT 안에 있지만 (`/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework`), SwiftPM의 테스트 러너가 이 프레임워크를 링크 시점엔 찾아도 런타임에 `dlopen`하지 못해 항상 실패한다(`Library not loaded: @rpath/Testing.framework/...`). `xcode-select -p`로 실제 Xcode.app 설치 여부를 먼저 확인하고, CLT뿐이면 XCTest 테스트 타겟을 만들지 말 것. 대신 검증용 실행 파일 타겟(예: `TaskflowVerify`처럼 `TaskflowCore`에 의존하는 별도 `executableTarget`)을 만들어 assertion을 직접 작성하고 `swift run <VerifyTargetName>`으로 실행한다 — `swift test`와 달리 일반 실행 파일이라 CLT만으로도 항상 동작한다. 전체 Xcode가 설치되어 있으면 (`xcode-select -p`가 `/Applications/Xcode.app/...`를 가리키면) 정석대로 XCTest/swift-testing 테스트 타겟을 써도 된다.

## 디자인 스펙 반영 시 주의

- `_workspace/01_design_spec/screens/*.md`의 스펙과 다르게 구현해야 할 기술적 이유(예: macOS에서 지원되지 않는 인터랙션)가 있으면, 임의로 다르게 만들지 말고 `_workspace/02_swiftui_developer_notes.md`에 사유를 남긴 뒤 design-integrator에게 확인을 요청한다.
- 색상/폰트/spacing은 하드코딩하지 않고 `DesignTokens`를 참조한다 — 나중에 디자인이 갱신되면 토큰만 바꿔 전체 반영이 가능해야 한다.
