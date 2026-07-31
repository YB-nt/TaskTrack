# TaskTrack (Taskflow)

Task Master(taskmaster-ai) 형식의 `tasks.md`를 읽어 진행률·오늘 할 일·마감 임박을 보여주는 개인용 macOS 앱.

## 화면

- **Dashboard** — 전체 진행률, 오늘 할 일, 마감 임박
- **Curriculum** — Phase별 Step 목록, 필터/검색
- **Step Detail** — 설명/체크리스트/완료 처리, `문제 X-Y` 하위 파일(예: `Phase2.md`) 자동 매칭
- **Sync** — 소스 파일 연결, 동기화 주기, 변경 이력

## 빌드 & 실행

```sh
swift build
swift run Taskflow        # 앱 실행
swift run TaskflowVerify  # 테스트 대체 실행 (XCTest 대신)
```

macOS 14+, Swift 6 툴체인 필요.

## 브랜치

`main`(안정) / `develop`(통합) / `feature/*` — git-flow.

## License

MIT — `LICENSE.txt` 참고.
