---
name: schedule-monitor-swift-orchestrator
description: "macOS Swift/SwiftUI 일정 모니터링 앱 개발을 위한 design-integrator + swiftui-developer + qa-inspector 에이전트 팀을 조율하는 오케스트레이터. Claude Design에서 만든 디자인을 Claude Code export로 반영하거나, 새 기능을 구현하거나, 화면을 만들거나, 빌드/QA를 실행할 때 사용. 예: '디자인 export 반영해줘', '일정 모니터링 앱에 OO 기능 추가해줘', 'SwiftUI 화면 구현해줘', '빌드 에러 고쳐줘'. 후속 작업에도 반드시 사용: 다시 구현해줘, 디자인 다시 반영해줘, 기능 수정/보완, QA 다시 돌려줘, 이전 결과 개선해줘."
---

# Schedule Monitor Swift Orchestrator

macOS Swift/SwiftUI 기반 일정 모니터링 앱을, "Claude Design에서 디자인 제작 → Claude Code export로 반입 → SwiftUI 구현 → QA 검증" 흐름으로 개발하기 위한 3인 에이전트 팀을 조율한다.

## 실행 모드: 에이전트 팀 (기본) — 단, 이 환경에서는 폴백 필요

design-integrator ↔ swiftui-developer ↔ qa-inspector 3자가 실시간으로 질문·수정 요청을 주고받아야 하는 생성-검증 + 파이프라인 복합 패턴이므로 에이전트 팀이 기본이다.

> **환경 확인 필수 (2026-07-30 확인됨):** 이 프로젝트가 실행되는 실제 Claude Code CLI 세션에는 `TeamCreate`/`TeamDelete`, 그리고 assignee·depends_on을 가진 공유 작업 목록형 `TaskCreate`가 **툴로 존재하지 않는다** (`ToolSearch`로 확인 — `SendMessage`는 존재하지만 팀 없이는 "이름으로 메시지 보낼 대상"이 없다). 존재하는 `TaskCreate`/`TaskList`/`TaskUpdate`는 세션 개인 할일 목록일 뿐이다. 또한 `Agent` 도구는 "사용자가 명시적으로 서브에이전트 사용을 요청하지 않으면 스폰하지 말 것"이 시스템 지침으로 박혀 있다.
> **폴백:** 아래 Phase 2의 `TeamCreate` 블록을 그대로 실행하지 말 것 — 대신 design-integrator/swiftui-developer/qa-inspector 각 `.claude/agents/*.md`를 리더(메인 에이전트) 자신이 순서대로 내면화하여 직접 수행한다 (파일을 Read하고 그 역할·원칙·검증 체크리스트를 따르되, 별도 에이전트를 스폰하지 않음). Phase 3의 "팀원 간 SendMessage" 대신, 리더가 스스로 "디자인 반입 → 구현 → 검증"을 순차 수행하고 각 단계 산출물을 `_workspace/`에 저장하는 것으로 대체한다. 세션이 실제로 `TeamCreate`를 지원하는 환경으로 바뀌면 (다른 Claude Code 제품 표면 등) 원래의 팀 모드를 그대로 사용해도 된다 — 매번 먼저 `ToolSearch("select:TeamCreate")`로 확인할 것.

## 에이전트 구성

| 팀원 | agent_type | 역할 | 스킬 | 출력 |
|------|-----------|------|------|------|
| design-integrator | `design-integrator` (커스텀) | Claude Design export → 디자인 토큰/스펙 변환 | design-export-intake | `_workspace/01_design_spec/` |
| swiftui-developer | `swiftui-developer` (커스텀) | SwiftUI 구현, 모니터링/알림 로직 | swiftui-app-development | 프로젝트 소스 + `_workspace/02_swiftui_developer_notes.md` |
| qa-inspector | `general-purpose` (빌트인, 프롬프트에서 `.claude/agents/qa-inspector.md` 역할 로드 지시) | 경계면 정합성·빌드·디자인 충실도 검증 | swift-integration-qa | `_workspace/03_qa_report_{n}.md` |

> 3명 — 소규모 팀 크기 가이드라인에 부합. qa-inspector를 general-purpose로 지정하는 이유는 QA가 빌드 실행과 grep 기반 교차 대조를 수행해야 하기 때문이다 (읽기 전용 타입으로는 불가능).

## 워크플로우

### Phase 0: 컨텍스트 확인 (후속 작업 지원)

1. `_workspace/` 존재 여부 확인
2. `design-exports/` 하위에 미처리 파일(= `_processed/`로 아직 옮겨지지 않은 파일) 존재 여부 확인
3. 요청 유형 판단:
   - `design-exports/`에 미처리 파일이 있고 사용자가 디자인 반영을 언급 → **디자인 통합 우선 실행** (design-integrator부터)
   - 사용자가 특정 기능 구현/수정을 요청 → **기능 개발 실행** (디자인 스펙이 이미 있으면 참조, 없으면 스펙 없이 진행하되 나중에 디자인이 반입되면 재조정이 필요할 수 있음을 사용자에게 안내)
   - `_workspace/` 존재 + 부분 수정 요청("이 화면만 다시", "QA만 다시 돌려줘") → **부분 재실행**, 해당 에이전트만 재호출
   - `_workspace/` 미존재 → **초기 실행**
4. 부분 재실행 시 이전 산출물 경로를 해당 에이전트 프롬프트에 포함하여, 이어서 작업하도록 지시한다 (처음부터 다시 만들지 않는다).

### Phase 1: 준비

1. `design-exports/` 폴더가 없으면 생성한다. 없던 경우 사용자에게 "여기에 Claude Design export 결과물을 넣으면 다음 실행 때 자동으로 반영됩니다"라고 안내한다.
2. `_workspace/` 생성 (초기 실행) 또는 새 실행 시 기존 `_workspace/`를 `_workspace_{YYYYMMDD_HHMMSS}/`로 이동 후 재생성
3. 사용자 요청을 작업 단위로 분해하여 `_workspace/00_input/request.md`에 기록 (요청 원문 + Phase 0 판단 결과)

**주의:** 일정 모니터링 앱의 구체적 기능 범위(외부 캘린더 연동 여부, 서버 필요 여부)는 아직 확정되지 않았다. 이는 누락이 아니라 의도된 상태 — 매 실행마다 사용자가 제공하는 구체적 요청 범위를 기준으로 작업하고, 범위를 임의로 확장하지 않는다.

### Phase 2: 팀 구성

```
TeamCreate(
  team_name: "schedule-app-team",
  members: [
    { name: "design-integrator", agent_type: "design-integrator", model: "opus",
      prompt: "design-exports/의 신규 산출물을 처리하여 _workspace/01_design_spec/를 생성/갱신하라. [Phase 0/1에서 파악한 구체적 요청 내용]" },
    { name: "swiftui-developer", agent_type: "swiftui-developer", model: "opus",
      prompt: "[구체적 기능/화면 요청 내용]을 구현하라. 디자인 스펙이 있으면 _workspace/01_design_spec/를 참조하라." },
    { name: "qa-inspector", agent_type: "general-purpose", model: "opus",
      prompt: "먼저 .claude/agents/qa-inspector.md를 Read하여 역할과 원칙을 따르라. 이번 실행에서 구현/변경된 모듈을 swift-integration-qa 스킬 절차에 따라 검증하라." }
  ]
)
```

작업 등록 (디자인 통합이 필요한 경우와 아닌 경우로 분기):

```
# 디자인 통합이 필요한 경우
TaskCreate(tasks: [
  { title: "디자인 export 반입", assignee: "design-integrator" },
  { title: "SwiftUI 구현", assignee: "swiftui-developer", depends_on: ["디자인 export 반입"] },
  { title: "통합 QA", assignee: "qa-inspector", depends_on: ["SwiftUI 구현"] }
])

# 기능 개발만 필요한 경우 (디자인 통합 불필요)
TaskCreate(tasks: [
  { title: "SwiftUI 구현", assignee: "swiftui-developer" },
  { title: "통합 QA", assignee: "qa-inspector", depends_on: ["SwiftUI 구현"] }
])
```

### Phase 3: 실행 (팀 자체 조율)

**실행 방식:** 팀원들이 공유 작업 목록에서 작업을 요청(claim)하고 SendMessage로 직접 소통한다.

- design-integrator가 디자인 스펙 완성 시 swiftui-developer에게 SendMessage로 경로와 변경 요약 전달
- swiftui-developer가 특정 화면/모듈 구현을 완료하는 즉시(전체 완료를 기다리지 않고) qa-inspector에게 검증 요청 — incremental QA
- qa-inspector가 FIX/REDO 발견 시 swiftui-developer에게 파일:라인 단위로 SendMessage, 최대 2회 재검증 루프
- 디자인 의도가 불명확하면 swiftui-developer가 design-integrator에게 직접 질문
- 리더는 팀원 유휴 알림을 모니터링하고, 막힌 팀원이 있으면 SendMessage로 개입

### Phase 4: 통합 및 보고

1. 모든 작업 완료 대기 (TaskGet으로 확인)
2. `_workspace/01_design_spec/INTAKE_REPORT.md`, `_workspace/02_swiftui_developer_notes.md`, `_workspace/03_qa_report_*.md`를 Read하여 종합
3. `_workspace/04_summary.md` 생성 — 이번 실행에서 반영/구현된 것, 남은 FIX/REDO 항목, 다음 실행 시 참고할 사항

### Phase 5: 정리

1. 팀원들에게 종료 요청 (SendMessage) 후 TeamDelete
2. `_workspace/` 보존 (감사 추적용, 삭제하지 않음)
3. `design-exports/`의 처리된 파일이 `_processed/`로 이동되었는지 확인
4. 사용자에게 결과 요약 보고 + 피드백 요청

## 데이터 흐름

```
design-exports/ (사용자가 놓은 export 산출물)
        │
        ▼ (design-integrator)
_workspace/01_design_spec/ ──SendMessage──► swiftui-developer
        │                                        │
        │                                        ▼ (구현, 모듈 단위 완성마다)
        │                                  프로젝트 소스 + 02_swiftui_developer_notes.md
        │                                        │
        └──────────(참조: ground truth)──────────┼──► qa-inspector (검증)
                                                   │         │
                                            SendMessage(FIX/REDO)
                                                   │         │
                                                   ◄─────────┘
                                                   ▼
                                          03_qa_report_*.md
                                                   │
                                                   ▼
                                        리더: 04_summary.md 통합
```

## 에러 핸들링

| 상황 | 전략 |
|------|------|
| design-exports/가 비어있는데 디자인 통합 요청 | design-integrator가 즉시 보고, 사용자에게 export 산출물 위치 안내 후 대기 |
| design export 형식을 전혀 알 수 없음 | 파싱 강행하지 않고 미처리로 기록, 사용자에게 형식 질문 |
| swiftui-developer 빌드 실패 2회 반복 | 리더에게 보고, 에러 로그와 시도 내역을 요약하여 사용자에게 전달 |
| qa-inspector REDO 판정 2회 반복 | 강제 PASS 처리하지 않음. "미해결"로 최종 리포트에 명시하고 사용자 판단 요청 |
| 팀원 1명 유휴/중단 | 리더가 SendMessage로 상태 확인 → 재시작 또는 남은 팀원에게 작업 재할당 |
| 팀원 간 정보 상충 (예: 디자인 스펙과 실제 사용성 요구가 충돌) | 삭제하지 않고 출처 병기, 사용자에게 판단 요청 |

## 팀 크기

3명 (design-integrator, swiftui-developer, qa-inspector) — 소규모 작업 가이드라인(2~3명)에 해당. 향후 백엔드/서버가 필요해지거나 기능 범위가 커지면 팀원 추가를 검토한다 (예: 서버 API가 필요해지면 `backend-developer` 추가).

## 테스트 시나리오

### 정상 흐름 — 디자인 반영
1. 사용자가 Claude Design export 산출물을 `design-exports/`에 넣고 "디자인 반영해줘" 요청
2. Phase 0에서 미처리 파일 감지 → 디자인 통합 우선 실행으로 판단
3. Phase 2에서 3인 팀 구성, 디자인 반입 → 구현 → QA 순서로 작업 등록
4. Phase 3에서 design-integrator가 스펙 작성 후 swiftui-developer에게 전달, swiftui-developer 구현, qa-inspector가 incremental 검증
5. Phase 4에서 `_workspace/04_summary.md` 생성
6. 예상 결과: 프로젝트에 새 SwiftUI 화면 반영 + QA PASS 리포트

### 정상 흐름 — 기능 개발만 (디자인 통합 불필요)
1. 사용자가 "일정 목록에 마감 임박 강조 표시 기능 추가해줘" 요청, 신규 디자인 export 없음
2. Phase 0에서 미처리 export 없음 확인 → 기능 개발 실행으로 판단
3. Phase 2에서 swiftui-developer + qa-inspector만으로 작업 등록 (design-integrator 작업 없음)
4. Phase 3~4 진행 후 요약 보고

### 에러 흐름
1. Phase 3에서 swiftui-developer가 빌드 실패를 2회 자체 수정 시도했으나 계속 실패
2. 리더가 감지 → 에러 로그와 시도 내역을 `_workspace/04_summary.md`에 "미해결" 항목으로 기록
3. 사용자에게 구체적 에러 내용과 함께 보고, 다음 실행 시 참고하도록 안내
