# 테스트 계획 (TEST_PLAN)

테스트 타깃: `HanwooPrototypeTests`(XCTest). 계산·판정·최적화는 UI와 분리해
순수 타입 수준에서 검증한다. 실행: Xcode ⌘U 또는
`xcodebuild test -scheme HanwooPrototype -destination 'platform=iOS Simulator,name=iPhone 17'`.

## 1. 계산 엔진 (CalculationEngineTests)

- DM 환산: 수분 60% 원료 10kg → 건물 4kg.
- 가중평균: 두 원료 혼합의 CP %DM 손계산 대조.
- 수분%: 물(성분 없음 라인) 포함 시 총량 반영·영양소 불변.
- 빈 배합/건물 0 → 안전 반환(크래시 금지).
- g 단위 라인 kg 환산.

## 2. 판정 (ClassificationTests)

- 각 축 경계값: 적정 하한/상한, 주의 경계, 부족/과잉 진입값.
- EE 상한형: 5.0 적정, 5.1 주의, 6.1 과잉.
- 수분 밴드: 40~45 적정, 36/49 주의 경계, 하드맥스 50.

## 3. 최적화 엔진 (CorrectionEngineTests)

골든 케이스(기대 결과 고정):

- 경기TMR 3000kg → 완전 해결(isFullyResolved), 총량 3000.0kg 유지.
- CP 부족 배합(최대 CP 9.5% < 기준 14%) → noSolution + "단백질원 추가" 한계 문구.
- 칼슘원 부재 배합 → noSolution + "칼슘원 추가" 한계 문구 + 참고안 존재.
- 유지 케이스: 전 축 적정 배합 → maintenance 추천.

불변식(모든 케이스 공통):

- 최종안 총 원물 kg = 원 배합 총량 (±0.01).
- 액션 원료는 전부 원 배합에 존재(in-mix). add 액션 없음.
- 음수 kg 없음. 잠금 원료 불변. min/max·조정폭 준수(P2 제약 테스트).
- 결정론: 같은 입력 2회 실행 → 동일 액션 목록.
- simulatedMetrics는 CalculationEngine 재계산 값과 일치.

민감도: 원료 1종 ±1% 변화 시 추천 방향(증감 부호) 유지.

## 4. 영속화 (RepositoryTests)

- 저장→복구 라운드트립(배합, 분석 이력, 사용자 원료).
- 손상 JSON 혼입 시 해당 레코드만 스킵.
- algorithmVersion 기록 확인.

## 5. E2E 스모크 (시뮬레이터 수동/스크립트)

입력→분석→판정→시뮬레이션→추천→저장→이력 확인→CSV/PDF 내보내기.
사용자 원료 추가/수정/삭제가 계산에 반영(기존 검증 시나리오 재사용:
CP 12.6→35.1→271.6→12.6).

## 6. 릴리즈 스모크

Release 구성 빌드 성공, 첫 실행 온보딩, 시드 배합 분석 정상, 다크모드/iPad 레이아웃.

## 통과 기준

P4 유닛 테스트 전부 green + E2E 스모크 체크리스트 완료가 릴리즈 조건이다.
실패 테스트가 있는 상태로 릴리즈하지 않는다.
