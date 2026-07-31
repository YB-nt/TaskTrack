<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a name="readme-top"></a>

<!-- PROJECT SHIELDS -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/YB-nt/TaskTrack">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">TaskTrack (Taskflow)</h3>

  <p align="center">
    Task Master 형식 마크다운(tasks.md) 기반 일정 파악 macOS 네이티브 앱
    <br />
    <a href="https://github.com/YB-nt/TaskTrack/issues">Report Bug</a>
    ·
    <a href="https://github.com/YB-nt/TaskTrack/issues">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project

<!-- 스크린샷 추가 예정 -->

Task Master(taskmaster-ai) 형식으로 작성된 `tasks.md`/`tasks_v2.md`를 읽어 진행률·오늘 할 일·마감 임박·락 상태를 파악하는 macOS 앱이다. 별도 오버레이 DB 없이 원본 `.md` 파일 자체를 소스 오브 트루스로 삼아 in-place로 읽고 쓴다.

주요 화면:
* **Dashboard** — 전체 진행률, 오늘 할 일, 마감 임박
* **Curriculum** — Phase별 Step 목록, 필터/검색
* **Step Detail** — 설명/선행조건/체크리스트/완료 처리, `문제 X-Y` 형식의 하위 파일(예: `Phase2.md`)이 등록되어 있으면 해당 상세 실행 문서를 함께 표시
* **Sync** — 연결된 `tasks.md` 경로, 통계, 동기화 주기(Manual/Hourly/Realtime), 변경 이력, 하위 파일 등록/해제

디자인은 Claude Design에서 제작한 다크 테마("nocturne")를 macOS 앱 셸(사이드바 내비게이션)로 포팅한 것이다.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With

* [![Swift][Swift-badge]][Swift-url]
* SwiftUI (macOS 14+, `@Observable`)
* Swift Package Manager (외부 의존성 없음)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

* macOS 14 이상
* Swift 6 툴체인 (Xcode 16+ 또는 Command Line Tools)

### Installation

1. 레포 클론
   ```sh
   git clone https://github.com/YB-nt/TaskTrack.git
   cd TaskTrack
   ```
2. 빌드
   ```sh
   swift build
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE EXAMPLES -->
## Usage

앱 실행:
```sh
swift run Taskflow
```
실행 후 Sync 탭에서 "Add File"로 실제 `tasks.md`(또는 `tasks_v2.md`)를 선택하면 파싱된 일정이 각 화면에 반영된다. 같은 탭의 "하위 파일" 카드에서 `Phase2.md` 같은 문제별 상세 문서를 등록하면, `문제 X-Y` 토큰이 일치하는 항목의 Step Detail에 상세 실행 문서가 함께 표시된다.

테스트 대체 실행(이 프로젝트는 CLT 전용 환경에서 XCTest 런타임 링크가 되지 않아, 일반 executable로 검증 스위트를 대체한다):
```sh
swift run TaskflowVerify
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ROADMAP -->
## Roadmap

- [x] 파서/스케줄엔진/디자인시스템/SwiftUI 화면 4개 (Dashboard/Curriculum/Step Detail/Sync)
- [x] `Phase2.md`류 하위 파일 자동 교차연결 (`문제 X-Y` 토큰 매칭)
- [ ] 다중 소스 파일 동시 동기화 (현재는 단일 `tasks.md`)
- [ ] Inter 폰트 번들링
- [ ] 앱 아이콘 / 샌드박스 / App Store 배포 설정

See the [open issues](https://github.com/YB-nt/TaskTrack/issues) for a full list of proposed features (and known issues).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

이 프로젝트는 [git-flow](https://nvie.com/posts/a-successful-git-branching-model/) 브랜치 전략을 따른다.

* `main` — 릴리스된 안정 버전만 존재
* `develop` — 다음 릴리스를 위한 통합 브랜치
* `feature/*` — `develop`에서 분기, 기능 구현 후 `develop`로 병합
* `release/*` — `develop`에서 분기, 릴리스 준비 후 `main`과 `develop` 양쪽에 병합 + 태그
* `hotfix/*` — `main`에서 분기, 긴급 수정 후 `main`과 `develop` 양쪽에 병합

1. `develop`에서 Feature Branch 생성 (`git checkout -b feature/AmazingFeature develop`)
2. 변경사항 커밋 (`git commit -m 'Add some AmazingFeature'`)
3. 브랜치 푸시 (`git push origin feature/AmazingFeature`)
4. `develop`을 대상으로 Pull Request 오픈

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

[@YB-nt](https://github.com/YB-nt)

Project Link: [https://github.com/YB-nt/TaskTrack](https://github.com/YB-nt/TaskTrack)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/YB-nt/TaskTrack.svg?style=for-the-badge
[contributors-url]: https://github.com/YB-nt/TaskTrack/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/YB-nt/TaskTrack.svg?style=for-the-badge
[forks-url]: https://github.com/YB-nt/TaskTrack/network/members
[stars-shield]: https://img.shields.io/github/stars/YB-nt/TaskTrack.svg?style=for-the-badge
[stars-url]: https://github.com/YB-nt/TaskTrack/stargazers
[issues-shield]: https://img.shields.io/github/issues/YB-nt/TaskTrack.svg?style=for-the-badge
[issues-url]: https://github.com/YB-nt/TaskTrack/issues
[license-shield]: https://img.shields.io/github/license/YB-nt/TaskTrack.svg?style=for-the-badge
[license-url]: https://github.com/YB-nt/TaskTrack/blob/main/LICENSE.txt
[Swift-badge]: https://img.shields.io/badge/Swift-F54A2A?style=for-the-badge&logo=swift&logoColor=white
[Swift-url]: https://swift.org
