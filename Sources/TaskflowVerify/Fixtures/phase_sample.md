# Phase 2 — Linux 시스템 프로그래밍 (샘플)

## Week 4 — 파일 I/O와 파일 디스크립터

### 문제 6-1. open/read/write/close vs fopen/fread — 파일 복사 두 벌 만들기

**목표**: 버퍼링된 I/O와 시스템콜 직접 호출의 차이를 체감한다.

**요구사항**:
```c
int copy_file_syscall(const char *src, const char *dst);
```

**성공 기준**:
- diff 결과 원본과 100% 동일

---

### 문제 6-2. lseek — 랜덤 액세스와 파일 오프셋

**목표**: 파일 오프셋 개념을 확인한다.

**성공 기준**:
- write_at으로 기존 파일 중간을 덮어썼을 때 앞뒤 데이터 보존

---

### 체크포인트 (문제 아님) — fd와 소켓의 연결고리

문제 번호가 없는 섹션은 매칭되지 않아야 한다.
