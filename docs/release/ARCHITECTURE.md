# 아키텍처 (ARCHITECTURE)

플랫폼: iOS(SwiftUI), 로컬 단독 동작. 서버·Supabase는 선택 사항이며 핵심 플로우에
관여하지 않는다.

## 모듈 구성

```
UI (SwiftUI Views)
 └─ PrototypeStore (@MainActor ObservableObject; 화면 상태 + 유스케이스)
     ├─ 계산(평가) 엔진   CalculationEngine        — 순수 struct
     ├─ 최적화·시뮬레이션  CorrectionEngine         — 순수 struct
     ├─ 설명              RecommendationExplanation — 엔진 산출물의 구조화 뷰
     └─ 영속화            Repository 프로토콜 군     — UserDefaults JSON 구현
```

| 모듈 | 파일 | 규칙 |
| --- | --- | --- |
| 도메인 모델 | DomainModels.swift | 기준표(StageCriteria)·단위·밴드 정의. UI 비의존 |
| 원료 카탈로그 | IngredientCatalog.swift | 출처 주석 포함. 값 수정은 근거 문서 필수 |
| 검증 | 입력 화면 + 도메인 검증 함수 | 음수/비정상 값 차단, 실시간 총량 표시 |
| 계산(평가) | CalculationEngine.swift | 결정론. SwiftUI/스토어/저장소 비의존 |
| 최적화·시뮬레이션 | CorrectionEngine.swift | OPTIMIZATION_ENGINE.md 참조 |
| 설명 | CorrectionEngine 내 Recommendation 조립 | 수치는 전부 계산 엔진 산출값 인용 |
| 영속화 | Repositories.swift | 프로토콜 뒤 UserDefaults. SwiftData/서버 교체 가능 |
| 내보내기 | ExportService | CSV/PDF 생성, ShareLink 연동 |
| UI | *View.swift + DesignSystem.swift | 비즈니스 규칙·기준값 하드코딩 금지 |

## 경계 규칙

- 엔진은 `IngredientProviding`(원료 조회)만 의존한다. 스토어·UserDefaults·SwiftUI
  참조 금지. 이 경계 덕에 향후 로컬 ML/승인된 AI 공급자가 후보 생성부를
  대체해도 검증·정규화·UI는 재작성이 필요 없다.
- 스토어는 얇은 브릿지 extension(`PrototypeStore+CalculationEngine/+CorrectionEngine`)
  으로 엔진에 위임한다.
- 저장 분석에는 배합 스냅샷과 `algorithmVersion`을 함께 기록한다.

## 데이터 흐름 (핵심 플로우)

```
원료 선택/입력(kg) ─▶ 검증 ─▶ 계산 엔진(영양값) ─▶ 판정(기준표)
      ▲                                            │
      │                                            ▼
사용자 원료 편집                        증감 시뮬레이션(수동 슬라이더 / 자동 최적화)
                                                   │
                                                   ▼
                            추천안(원료별 증감 kg, 총량 정규화) + 전후 비교
                                                   │
                                                   ▼
                                     저장(이력) / CSV·PDF 내보내기
```

## 세션·커뮤니티

로컬 로그인/커뮤니티는 UserDefaults 기반 로컬 폴백으로 유지한다. Supabase
연동 코드는 옵션으로 남기고 릴리즈 경로에서 필수화하지 않는다.
알려진 이슈(관리자 계정 하드코딩, 평문 비밀번호)는 RELEASE_CHECKLIST에 기록.
