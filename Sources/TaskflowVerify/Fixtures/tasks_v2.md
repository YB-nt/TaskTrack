# TSN Lab S/W팀 지원 로드맵 — Taskmaster Tasks

**Project**: tsnlab-sw-application
**Source**: 지원 로드맵 v2 (2026-07-25 개정)
**Timeline**: Week 4 ~ Week 21 (2026-08 ~ 2026-12)
**Tag**: master
**Phase 2 상세 문서**: `Phase2.md` — 문제 6-1 ~ 11-3이 Task 1의 하위 ID(`1.x.y`)와 1:1 대응.

Week 1 = 2026-07-13 (Mon), per roadmap's "Week 1 = 2026년 7월 둘째 주" (dates are approximate)

---

## Task List

| ID | Title | Priority | Status | Dependencies | Window |
|----|-------|----------|--------|--------------|--------|
| 1 | Phase 2 — Linux 시스템 프로그래밍 | high | pending | none | W4–9 |
| 2 | Phase 2.5 — 드라이버 & HW–커널–앱 구술 | high | pending | 1 | W10–11 |

---

## Task 1 — Phase 2: Linux 시스템 프로그래밍

```
# Task ID: 1
# Title: Phase 2 — Linux 시스템 프로그래밍
# Status: pending
# Dependencies: none
# Priority: high
```

**Description**
JD 자격요건의 "기본적인 OS 지식(쓰레드, 메모리, 프로세스 관리)"를 직접 대응하는 필수 구간. Week 4–9, 6주.

**Details**
- **문제 단위 실행 문서는 `Phase2.md`.** 이 태스크는 진행 관리용이고, 각 문제의 요구사항·성공 기준·의도적 실패 정의는 `Phase2.md`가 원본이다.
- 총 23개 항목 = 문제 19개 + 체크포인트 3개 + 총정리 노트 1개.

**Test Strategy**
- [ ] `fork` 후 부모/자식 fd 테이블 상태를 말로 설명 (1.1.1 + 1.2.1)
- [x] `/proc/[pid]/maps` 출력을 보고 각 영역 지목 (1.2.4 + 1.3.1)

### Subtasks

**1.1 — Week 4: 파일 I/O와 파일 디스크립터** `pending` / deps: none
`Phase2.md § Week 4` — 문제 6-1 ~ 6-3 + 체크포인트 1개

| ID | Phase 2 항목 | 구현 대상 | 환경 | 의도적 실패 | Status |
|---|---|---|---|---|---|
| 1.1.1 | 문제 6-1 — 파일 복사 두 벌 | `copy_file_syscall` / `copy_file_stdio` | macOS | — | pending |
| 1.1.2 | 문제 6-2 — lseek·스파스 파일 | `write_at` / `read_at` | macOS | — | done |
| 1.1.3 | 문제 6-3 — dup2 리다이렉션 | `redirect_stdout_to_file` | macOS | — | pending |
| 1.1.4 | 체크포인트 — fd ↔ 소켓 연결고리 | 메모 1문단 + `strace` 관찰 로그 | Linux | — | pending |

**1.2 — Week 5: 프로세스 + `/proc` + 미니 shell(3일)** `in-progress` / deps: 1.1
`Phase2.md § Week 5` — 문제 7-1 ~ 7-4 + 체크포인트 1개

| ID | Phase 2 항목 | 구현 대상 | 환경 | 의도적 실패 | Status |
|---|---|---|---|---|---|
| 1.2.1 | 문제 7-1 — fork 기초, 메모리 독립성 | `demonstrate_fork` | macOS | — | done |
| 1.2.2 | 문제 7-2 — fork + exec 실행기 | `run_command` | macOS | — | in-progress |
| 1.2.3 | 문제 7-3 — 좀비 생성 / 회수 | `create_zombie_and_observe` | macOS | ● 좀비가 `Z`로 보여야 정답 | pending |

---

## Task 2 — Phase 2.5: 디바이스 드라이버 & 구술

```
# Task ID: 2
# Title: Phase 2.5 — 드라이버 & HW–드라이버–커널–앱 구술
# Status: pending
# Dependencies: 1
# Priority: high
```

**Description**
드라이버 구현은 JD 우대 항목이지만 "HW–드라이버–커널–애플리케이션 관계 설명"은 자격요건(필수). Week 10–11, 2주 상한.

**Test Strategy**
- [ ] 아래 write 경로 전체를 그림 없이 5분 안에 구술

### Subtasks

**2.1 — Week 10: 커널 모듈 기초** `pending` / deps: 1.3
- 커널 공간 vs 사용자 공간
- Hello World 모듈 → 모듈 파라미터 → 의도적 커널 패닉 1회

**2.2 — Week 11: 캐릭터 디바이스 + 구술 스크립트** `pending` / deps: 2.1
- `file_operations`, `open/read/write/release`, `ioctl` 1개
