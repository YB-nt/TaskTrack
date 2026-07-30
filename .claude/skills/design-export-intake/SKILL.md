---
name: design-export-intake
description: "Claude Design(claude.ai Design 기능)에서 만든 디자인 산출물을 Claude Code export로 전달받아 처리하는 스킬. export 형식이 SwiftUI/HTML 코드든, 이미지+스펙 문서든, JSON 디자인 토큰이든 상관없이 자동 감지하여 SwiftUI 프로젝트용 디자인 토큰과 화면/컴포넌트 스펙으로 변환한다. design-exports 폴더에 새 파일이 생기거나, '디자인 export 처리해줘', 'Claude Design에서 만든 거 반영해줘', '이 목업대로 스펙 뽑아줘' 요청 시 반드시 사용."
---

# Design Export Intake

Claude Design → Claude Code export 워크플로우는 아직 산출물 형식이 하나로 고정되어 있지 않다. 어떤 세션에서는 SwiftUI 코드가 통째로 넘어올 수 있고, 다른 세션에서는 이미지 스크린샷과 텍스트 설명만 넘어올 수도 있다. 이 스킬은 형식을 먼저 감지한 뒤 그에 맞는 추출 전략을 적용하는 절차를 정의한다.

## 인테이크 규칙

1. `design-exports/`를 스캔한다 (없으면 생성하고 사용자에게 여기에 export 산출물을 넣으라고 안내한다).
2. `design-exports/_processed/`는 이미 처리된 파일이 보관되는 위치이므로 건너뛴다.
3. 처리 대상 파일마다 아래 "형식 감지" 절차를 적용한다.
4. 처리 완료 후 원본을 `design-exports/_processed/{YYYYMMDD_HHMMSS}/`로 이동한다. **삭제하지 않는다** — 나중에 QA가 디자인 충실도를 검증할 때 원본이 유일한 기준(ground truth)이기 때문이다.

## 형식 감지

파일 확장자와 내용을 함께 본다. 확장자만으로 판단하면 예를 들어 `.json`이 디자인 토큰인지 임의의 데이터인지 구분할 수 없다.

| 신호 | 판단 | 추출 전략 |
|------|------|----------|
| `.swift` 파일이 View/struct 정의를 포함 | SwiftUI 코드 export | 코드 그대로 채택 여부 검토 → 프로젝트 명명 규칙에 맞게 정리 |
| `.html`/`.css` + 색상/폰트/여백 스타일 값 | 마크업 목업 | CSS 값을 Swift 타입으로 매핑 (아래 매핑표) |
| `.json`이 `color`/`typography`/`spacing` 등 디자인 관련 키를 포함 | 디자인 토큰 JSON | 키-값을 그대로 `DesignTokens.swift`에 매핑 |
| 이미지(`.png`/`.jpg`/`.svg`)만 있고 별도 스펙 텍스트 없음 | 시각 참조 전용 | 코드 추출 불가 — 육안으로 스펙 작성, 모든 수치값에 `(추정)` 표기 |
| 위 중 무엇에도 해당하지 않음 | 미확인 형식 | 파싱을 강행하지 않는다 — `INTAKE_REPORT.md`에 "미처리, 형식 불명"으로 기록하고 사용자에게 질문 |

한 export 안에 여러 형식이 섞여 있을 수 있다 (예: SwiftUI 코드 일부 + 스크린샷 일부). 이 경우 파일 단위로 각각 판단하고 섞어서 처리한다.

## CSS → Swift 값 매핑

HTML/CSS 목업에서 값을 추출할 때 사용하는 대응표:

| CSS | Swift |
|-----|-------|
| `color: #RRGGBB` / `background-color` | `Color(red:green:blue:)` 또는 hex 이니셜라이저 |
| `font-family` + `font-size` + `font-weight` | `Font.custom(_:size:)` 또는 시스템 폰트 매핑 + `.weight()` |
| `padding`/`margin` (px) | `CGFloat` — px 값을 그대로 point로 취급 (디자인이 웹 기준이 아니라 Mac 앱 기준으로 만들어졌다면 배율 보정 필요, 불확실하면 원본값과 함께 주석으로 남긴다) |
| `border-radius` | `.cornerRadius()` 값 |
| `box-shadow` | `.shadow(color:radius:x:y:)` — blur/spread를 radius로 근사, 근사임을 명시 |

## 출력 구조

```
_workspace/01_design_spec/
├── tokens/
│   └── DesignTokens.swift       # 색상/폰트/spacing 상수
├── screens/
│   └── {screen-name}.md         # 화면별 레이아웃, 컴포넌트 배치, 상태
├── components/
│   └── {component-name}.md      # 재사용 컴포넌트 스펙
├── assets/                       # 원본에서 복사한 이미지/아이콘
└── INTAKE_REPORT.md              # 처리 목록 + 감지 형식 + 추정치 + 미처리 항목
```

### DesignTokens.swift 스켈레톤

```swift
import SwiftUI

enum DesignTokens {
    enum Colors {
        static let primary = Color(red: 0, green: 0, blue: 0) // TODO: 실제 값으로 교체
    }
    enum Typography {
        static let heading = Font.system(size: 20, weight: .semibold)
    }
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
    }
}
```

### 화면 스펙 템플릿 (`screens/{screen-name}.md`)

```markdown
# {화면 이름}

## 레이아웃
[컴포넌트 배치, 계층 구조]

## 사용 컴포넌트
- {component-name} — [역할]

## 상태
| 상태 | 설명 |
|------|------|
| 기본 | ... |
| (있다면) 빈 상태/로딩/에러 | ... |

## 출처
원본: `design-exports/_processed/{timestamp}/{원본파일명}`
```

## INTAKE_REPORT.md 템플릿

```markdown
# Design Export 처리 보고

## 처리한 파일
| 파일 | 감지 형식 | 처리 결과 |
|------|----------|----------|

## 추정치 (원본에 명시적 값이 없어 육안/근사로 결정)
| 항목 | 추정값 | 근거 |

## 미처리
| 파일 | 사유 |
```

## 원칙

- **형식을 가정하지 말고 먼저 확인한다.** 다음 export가 이번과 같은 형식일 것이라 가정하지 않는다.
- **추정과 확정을 구분해서 기록한다.** swiftui-developer와 qa-inspector가 이 구분을 신뢰할 수 있어야 나중에 "왜 이 색이 이 값인지" 추적 가능하다.
- **원본은 항상 보존한다.** 디자인 충실도 검증의 유일한 기준이다.
