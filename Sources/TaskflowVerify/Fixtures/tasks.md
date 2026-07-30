# TSN Lab S/W팀 지원 로드맵 — Taskmaster Tasks

**Project**: tsnlab-sw-application
**Source**: 지원 로드맵 v2 (2026-07-25 개정)
**Timeline**: Week 4 ~ Week 21 (2026-08 ~ 2026-12)
**Tag**: master

---

## Task List

| ID | Title | Priority | Status | Dependencies | Window |
|----|-------|----------|--------|--------------|--------|
| 1 | Phase 2 — Linux 시스템 프로그래밍 | high | pending | none | W4–9 |
| 2 | Phase 2.5 — 드라이버 & HW–커널–앱 구술 | high | pending | 1 | W10–11 |
| 3 | Phase 3 — 소켓 프로그래밍 | high | pending | 1, 2 | W12–18 |
| 4 | 프로젝트 A — 비동기 소켓 서버 + 측정 하니스 | high | pending | 3 | W17–18 |
| 5 | Phase 4 — Zephyr RTOS (2주 상한) | medium | pending | 1, 2 | W19–20 |
| 6 | Phase 5 — TSN 이론 정리 | medium | pending | none | W21 |
| 7 | 트랙 B — 오픈소스 기여 | high | pending | none | W6–18 |
| 8 | 트랙 C — Python 브릿지 | medium | pending | 3.2, 3.3 | W15–18 |
| 9 | 트랙 D — 서류 A4 1장 | high | pending | none | W4–21 |
| 10 | 이력서(CV) 개정 | high | pending | 9.1 | W12 |
| 11 | 코딩 워밍업 (상시) | medium | pending | none | W4–21 |
| 12 | ★ 1차 지원 | high | pending | 2, 3.4, 9.2, 10 | W17 |
| 13 | ★ 2차 지원 / 보완 | high | pending | 4, 5, 6, 12 | W21 |
| 14 | 병행 지원 확대 & 손절 기준 | medium | pending | 12 | W17+ |

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
- v1 대비 재배분: 가상 메모리 1주 신설, 시그널+IPC 1주 통합, 미니 shell을 독립 주차에서 3일 과제로 축소.
- 시그널·IPC는 JD 비호명 항목 → "물어보면 답할 수 있는 수준"에서 정지.
- 컴파일 기준: `gcc -Wall -Wextra -std=c17 -g`, 경고 0개.

**Test Strategy**
- [ ] `fork` 후 부모/자식 fd 테이블 상태를 말로 설명
- [ ] `/proc/[pid]/maps` 출력을 보고 각 영역 지목
- [ ] race condition 재현 → 뮤텍스 수정 과정을 5분 내 시연
- [ ] "스레드 per 커넥션의 한계"를 컨텍스트 스위칭·스택 메모리 수치 근거로 설명

### Subtasks

**1.1 — Week 4: 파일 I/O와 파일 디스크립터** `pending` / deps: none
- `open/read/write/close/lseek`, `O_NONBLOCK`·`O_APPEND` 플래그
- fd 테이블, `dup`/`dup2`, fd = 커널 객체 핸들 구조
- `write()` 시스템 콜 vs `fwrite()` 라이브러리 버퍼링 차이
- **Phase 3 연결 지점**: "소켓도 fd다"의 성립 근거 확보
- 검증: `strace`로 자기 프로그램 시스템 콜 직접 관찰

**1.2 — Week 5: 프로세스 + /proc + 미니 shell(3일)** `pending` / deps: 1.1
- `fork/exec/wait/waitpid`, 종료 상태, 좀비·고아 프로세스
- `/proc/[pid]/status`, `/maps`, `/fd` 직접 관찰
- 미니 shell 범위 고정: 파이프 1단계(`pipe`+`dup2`) + 리다이렉션 + 내장 명령 2개
- **확장 금지**: 포트폴리오 차별화 0인 과제. 3일 초과 시 중단

**1.3 — Week 6: 가상 메모리 (v2 신설)** `pending` / deps: 1.2
- 가상↔물리 주소, 페이지, 페이지 테이블, MMU
- 메모리 레이아웃 text/data/bss/heap/stack — `/proc/[pid]/maps`로 실물 확인
- `brk`/`sbrk` vs `mmap`, malloc의 실제 동작
- `mmap` 파일 매핑 / 익명 매핑 실습
- 스택·힙 오버플로우 재현 + ASan 출력 읽기
- **구술 목표**: "사용자 공간 포인터를 커널이 그대로 역참조하면 왜 안 되는가" → Task 2.2로 직결

**1.4 — Week 7: 시그널 + IPC (통합 압축)** `pending` / deps: 1.3
- `signal` vs `sigaction`, async-signal-safe, `SIGPIPE`
- **`SIGPIPE`는 Phase 3 필수 지식** — 상대가 끊은 뒤 write 시 프로세스 사망 문제까지 확실히
- IPC: 파이프 / 유닉스 도메인 소켓 / 공유 메모리 — 개념 + 사용 시점만. 전부 구현 금지
- 실습: 유닉스 도메인 소켓 1개만 구현 (Phase 3 예열)

**1.5 — Week 8: 멀티스레딩 1** `pending` / deps: 1.4
- `pthread_create/join/detach`, 스레드 vs 프로세스(주소 공간 공유 관점)
- 뮤텍스, 조건 변수, race condition 직접 재현
- 데드락 4조건 + 직접 재현

**1.6 — Week 9: 멀티스레딩 2 + Phase 2 정리** `pending` / deps: 1.5
- ThreadSanitizer(`-fsanitize=thread`) race 탐지
- 재진입성, `errno`가 스레드별인 이유
- "왜 고성능 서버는 스레드 per 커넥션을 안 쓰는가" 답변 확보 → Phase 3 이벤트 루프 도입 근거
- 산출물: Phase 2 정리 노트 1장 (면접용, 스크립트 아님)

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
드라이버 구현은 JD 우대 항목이지만 **"HW–드라이버–커널–애플리케이션 관계 설명"은 자격요건(필수)**. 산출물은 코드가 아니라 5분짜리 구술 설명. Week 10–11, 2주 상한.

**Details**
- 캐릭터 디바이스를 만드는 목적 = 구술 설명에 실물 근거를 붙이기 위함.
- 환경: 라즈베리파이 5 (Phase 4와 동일 기기).
- v1의 "Week 12 인터럽트 & 디버깅 독립 주차"는 삭제 → 2.2에 흡수.
- 드라이버의 포트폴리오 포지셔닝 격하: 구술 자료 + README 1장.

**Test Strategy**
- [ ] 아래 write 경로 전체를 그림 없이 5분 안에 구술
- [ ] 각 단계마다 "여기서 실패하면 무슨 증상이 나는가" 1줄씩 대답
- [ ] `copy_to_user`/`copy_from_user` 대신 `memcpy`를 쓰면 안 되는 이유 설명

### Subtasks

**2.1 — Week 10: 커널 모듈 기초** `pending` / deps: 1.3
- 커널 공간 vs 사용자 공간 (Task 1.3 위에 적층)
- `insmod`/`rmmod`/`lsmod`/`dmesg` 워크플로우, `printk` 로그 레벨
- Hello World 모듈 → 모듈 파라미터 → 의도적 커널 패닉 1회

**2.2 — Week 11: 캐릭터 디바이스 + 구술 스크립트** `pending` / deps: 2.1
- `file_operations`, `open/read/write/release`, `ioctl` 1개
- `copy_to_user` / `copy_from_user` — 이 Phase의 핵심 질문
- `/dev` 노드 생성(udev), 사용자 공간 테스트 프로그램, `echo`/`cat` 검증
- 인터럽트는 개념 + 아래 경로 설명까지만

---

## Task 3 — Phase 3: 소켓 프로그래밍

```
# Task ID: 3
# Title: Phase 3 — 소켓 프로그래밍 (필수·핵심, 최대 배분)
# Status: pending
# Dependencies: 1, 2
# Priority: high
```

**Description**
JD가 괄호까지 쳐서 명시한 필수 항목 — "Network Socket Programming (Async Socket I/O, Raw Socket 등)". 합격/불합격이 갈리는 구간. Week 12–18, 7주.

**Details**
- v1의 결함: "epoll 기반 에코 서버"에서 종료. 에코 서버는 튜토리얼 종착점이지 실력 증명이 아님.
- v2 목표: 실제 서버에서 터지는 문제를 직접 밟아보고 재현 로그를 남길 것.

**Test Strategy**
- [ ] TCP 3-way handshake ↔ API 대응, TIME_WAIT, 부분 read/write가 정상인 이유 설명
- [ ] epoll LT vs ET 차이를 직접 구현한 두 버전으로 시연
- [ ] ET에서 read를 EAGAIN까지 안 돌렸을 때의 증상 재현
- [ ] raw socket 패킷을 tcpdump/Wireshark 캡처로 검증
- [ ] epoll vs io_uring을 자기 측정 숫자로 비교 설명

### Subtasks

**3.1 — Week 12: TCP 소켓 기초** `pending` / deps: 1.6
- `socket/bind/listen/accept/connect`, 3-way handshake와 API 대응
- 단일 클라이언트 에코 서버 — **3일 내 종료**
- `SO_REUSEADDR`가 필요한 이유(TIME_WAIT), `SIGPIPE` 무시 처리

**3.2 — Week 13: 논블로킹 + epoll** `pending` / deps: 3.1
- `fcntl` 논블로킹, `EAGAIN`/`EWOULDBLOCK`
- `epoll_create1/epoll_ctl/epoll_wait`
- LT와 ET **둘 다 구현**해서 동작 차이 직접 관찰

**3.3 — Week 14: 이벤트 루프의 실전 문제 (v2 신설, 최중요)** `pending` / deps: 3.2
- **부분 write**: 연결별 출력 버퍼 큐 구현 → `EPOLLOUT` 등록/해제
- **백프레셔**: 느린 클라이언트로 인한 메모리 무한 증가 → 버퍼 상한 + 초과 시 연결 종료 정책
- **연결 종료**: `read()` 0 반환, `EPOLLRDHUP`/`EPOLLHUP`/`EPOLLERR` 구분

**3.4 — Week 15: Raw Socket (JD 명시 필수)** `pending` / deps: 3.3
- `AF_PACKET` / `SOCK_RAW`, `CAP_NET_RAW` 권한
- 이더넷/IP/ICMP/ARP 헤더 직접 구성, 체크섬, 바이트 오더

**3.5 — Week 16: io_uring** `pending` / deps: 3.3
- SQ/CQ 링, 커널-사용자 공유 메모리, 시스템 콜 횟수 감소 원리
- liburing 에코 서버 (3.3 epoll 버전과 동일 프로토콜)

**3.6 — Week 17–18: 프로젝트 A 마감** `pending` / deps: 3.4, 3.5, 8
- Task 4로 분리 관리

---

## Task 4 — 프로젝트 A: 비동기 소켓 서버 + 측정 하니스

```
# Task ID: 4
# Title: 프로젝트 A — 비동기 소켓 서버 + 측정 하니스
# Status: pending
# Dependencies: 3
# Priority: high
```

**Description**
v1의 "에코 서버 + raw socket 툴"을 **측정 가능한 단일 프로젝트**로 재구성. Week 17–18 마감.

**Details — 구성**
1. epoll(ET) 논블로킹 TCP 서버 — 출력 버퍼 큐, 백프레셔, 타임아웃, 정상 종료 포함
2. io_uring 백엔드 (동일 인터페이스, 백엔드 교체 가능 구조)
3. Python 부하 생성·측정 하니스 (Task 8)
4. raw socket 툴 2종 (ping 클론, ARP 스캐너) — 별도 디렉터리

**Test Strategy**
- [ ] README만 읽고 제3자가 빌드·실행·재현 가능
- [ ] 3자 비교표에 실측 숫자가 채워져 있음
- [ ] 실패 기록 3건 이상이 원인·해결과 함께 서술됨

---

## Task 5 — Phase 4: Zephyr RTOS

```
# Task ID: 5
# Title: Phase 4 — Zephyr RTOS (2주 상한 고정)
# Status: pending
# Dependencies: 1, 2
# Priority: medium
```

**Description**
JD 우대 항목("FreeRTOS, Zephyr 등 RTOS Application 구현 가능자 우대"). Week 19–20.

**Details**
- **2주 상한 절대 준수.** 초과 조짐 시 Zephyr를 줄이지 말고 프로젝트 B를 줄일 것.

**Test Strategy**
- [ ] 스레드 모델/스케줄링/메모리 관리/드라이버 모델/인터럽트 지연 비교표 채움

---

## Task 6 — Phase 5: TSN 이론 정리

```
# Task ID: 6
# Title: Phase 5 — TSN 이론 정리
# Status: pending
# Dependencies: none
# Priority: medium
```

**Description**
Week 21, 1~2일. "면접에서 물어보면 답할 수 있는 수준"까지만.

**Details**
- 802.1AS (gPTP), 802.1Qbv (TAS), 802.1CB (FRER), 10Base-T1S

**Test Strategy**
- [ ] 위 5개 항목을 각 1분 내 구술

---

## Task 7 — 트랙 B: 오픈소스 기여

```
# Task ID: 7
# Title: 트랙 B — 오픈소스 기여
# Status: pending
# Dependencies: none
# Priority: high
```

**Description**
Week 6–18, 주 2~3시간 고정. **Week 18까지 머지된 PR 1~3개.**

**Details**
- 진입 경로: 문서 수정 → 테스트/샘플 보강 → 보드 지원 사소한 수정 → Packetvisor 이슈

**Test Strategy**
- [ ] Week 18 기준 머지 PR ≥ 1

---

## Task 8 — 트랙 C: Python 브릿지

```
# Task ID: 8
# Title: 트랙 C — Python 측정 하니스
# Status: pending
# Dependencies: 3.2, 3.3
# Priority: medium
```

**Description**
Week 15–18, 프로젝트 A에 흡수.

**Details**
- load_gen.py / measure.py / scenarios.py / regress.py / report.py

**Test Strategy**
- [ ] `regress.py`가 의도적으로 성능을 악화시킨 커밋에서 실패 반환

---

## Task 9 — 트랙 D: 서류 A4 1장

```
# Task ID: 9
# Title: 트랙 D — 서류 A4 1장 설계
# Status: pending
# Dependencies: none
# Priority: high
```

**Description**
Week 4–21 상시(주 30분), Week 12 초안 완성.

**Details**
- 지원 이유 3줄+, 머지된 PR 링크, 프로젝트 A 측정 숫자, 근무 이력, 공백기, 거주지

### Subtasks

**9.1 — Week 12: A4 1장 초안** `pending` / deps: none
- 6개 항목 자리만 잡고 채울 수 있는 것부터 채움

**9.2 — Week 4–16: 지원 이유 메모 상시 축적** `pending` / deps: none
- 주 30분. 진행 중 느낀 점 한 줄씩

**9.3 — Week 21: 최종 갱신** `pending` / deps: 9.1, 12
- 1차 지원 피드백 + Phase 3~4 산출물 반영

---

## Task 10 — 이력서(CV) 개정

```
# Task ID: 10
# Title: 이력서(CV) 개정 — 지원 전 필수
# Status: pending
# Dependencies: 9.1
# Priority: high
```

**Description**
현행 2페이지 CV는 이 회사 서류로 그대로 쓸 수 없음. A4 1장 별도 버전 신규 작성.

**Test Strategy**
- [ ] 프로젝트 간 중복 문구 0개
- [ ] Skills에 C / Linux / Socket / epoll / io_uring 반영

---

## Task 11 — 코딩 워밍업 (상시)

```
# Task ID: 11
# Title: 코딩 워밍업 — 주 2회 20분
# Status: pending
# Dependencies: none
# Priority: medium
```

**Description**
주 2회, 회당 20분. 문자열·배열·중첩 반복문 수준의 짧은 문제.

**Test Strategy**
- [ ] 주 2회 기록 누락 없음

---

## Task 12 — ★ 1차 지원 (Week 17)

```
# Task ID: 12
# Title: 1차 지원 — 필수 요건 충족 상태
# Status: pending
# Dependencies: 2, 3.4, 9.2, 10
# Priority: high
```

**Description**
Week 17 초 지원.

**Test Strategy**
- [ ] 지원 완료
- [ ] 면접 질문 전량 기록

---

## Task 13 — ★ 2차 지원 / 보완 (Week 21)

```
# Task ID: 13
# Title: 2차 지원 / 보완 제출
# Status: pending
# Dependencies: 4, 5, 6, 12
# Priority: high
```

**Description**
Week 21, 3~4일. Week 12 초안을 1차 지원 피드백 + Phase 3~4 산출물로 갱신 후 제출.

**Test Strategy**
- [ ] 서류에 측정 숫자 + PR 링크 + 공백기 설명 모두 포함

---

## Task 14 — 병행 지원 확대 & 손절 기준

```
# Task ID: 14
# Title: 병행 지원 확대 & 리스크 관리
# Status: pending
# Dependencies: 12
# Priority: medium
```

**Description**
단일 회사 타겟팅 리스크 해소. Week 17 1차 지원 시점에 동시 착수.

**Test Strategy**
- [ ] Week 17까지 병행 지원 대상 15곳 리스트업
- [ ] 2027-03 체크포인트 캘린더 등록
