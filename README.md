# 하누핏 Hanwoo TMR AI Recommendation MVP

한우 농가용 TMR 배합 분석 및 추천 서비스의 초기 구현체입니다.

## 구조

- `apps/api`: NestJS 기반 API
- `apps/ios`: SwiftUI 기반 iOS 설치형 프로토타입
- `packages/contracts`: OpenAPI와 맞춘 공유 타입
- `packages/domain`: 계산 엔진, 추천 엔진, 설명 템플릿
- `docs/openapi.yaml`: API 계약
- `docs/db/schema.sql`: PostgreSQL DDL
- `docs/seeds/ingredients.seed.json`: 최소 원료 seed
- `docs/development-operating-model.md`: 단계형 개발 운영안
- `docs/releases`: 단계별 릴리즈 기록

## 현재 포함 범위

- OpenAPI v1 초안
- PostgreSQL DDL 초안
- 원료 12종 seed JSON
- 분석/추천 순수 도메인 로직
- API 초기 골격
- iOS 설치형 프로토타입 골격

## 개발 원칙

- 모든 농장 데이터는 `farm_id` 스코프로 강제합니다.
- `analysis_runs`는 재현 가능한 스냅샷 저장을 기본으로 합니다.
- `recommendation_memos`는 append-only 이력 테이블로 유지합니다.
- 프론트는 서버 결과를 진실 소스로 사용하고 클라이언트 재계산을 하지 않습니다.

## 실행 환경

- Node.js 20 이상 권장
- pnpm 10.7.0
- iOS 앱 실행: macOS + Xcode 필요
- Windows 실행: API, 도메인 로직, 타입체크, 테스트는 가능하지만 iOS Simulator 실행은 불가

## 처음 받았을 때 설치

```bash
cd feedingsystem
corepack enable
corepack pnpm install
```

Windows에서는 프로젝트를 받은 폴더에서 동일하게 실행합니다.

```powershell
corepack enable
corepack pnpm install
```

## API 실행

루트에서 API 개발 서버를 실행합니다.

```bash
corepack pnpm dev
```

동일한 명령을 직접 필터로 실행할 수도 있습니다.

```bash
corepack pnpm --filter @feedingsystem/api dev
```

현재 API는 NestJS 초기 골격입니다. iOS 프로토타입은 목데이터 기반이므로, 앱 화면 확인만 할 때는 API 서버가 필수는 아닙니다.

## 검증 명령

```bash
corepack pnpm typecheck
corepack pnpm test
corepack pnpm build
```

## iOS 앱 실행: macOS

Xcode에서 프로젝트를 엽니다.

```bash
open apps/ios/HanwooPrototype/HanwooPrototype.xcodeproj
```

Xcode에서 다음 순서로 실행합니다.

1. 실행 대상에서 `iPhone Simulator`를 선택합니다.
2. 상단 `Run` 버튼을 누르면 시뮬레이터가 자동으로 켜지고 앱이 설치됩니다.
3. 실제 아이폰에 설치하려면 `Signing & Capabilities`에서 본인 Apple ID Team을 선택한 뒤, 연결된 iPhone을 실행 대상으로 고릅니다.

터미널에서 Xcode를 열 수 없는 경우 Finder에서 아래 파일을 더블클릭합니다.

```text
apps/ios/HanwooPrototype/HanwooPrototype.xcodeproj
```

## iOS Simulator 실행 조건

iOS Simulator는 Xcode에 포함된 macOS 전용 도구입니다. 따라서 Windows에서는 iOS Simulator를 직접 실행할 수 없습니다.

Windows에서 가능한 작업은 다음과 같습니다.

- API 서버 실행
- `packages/domain` 계산/추천 로직 개발
- TypeScript 타입체크 및 테스트
- 문서 수정
- GitHub 업로드 및 코드 리뷰

Windows에서 iOS 앱을 확인하려면 다음 중 하나가 필요합니다.

- Mac에서 Xcode로 실행
- Mac mini, MacBook, iMac 등 원격 Mac 사용
- 클라우드 Mac 서비스 사용
- TestFlight 또는 실제 기기에 설치된 빌드 공유

## iOS 프로토타입 범위

- Xcode에서 `apps/ios/HanwooPrototype/HanwooPrototype.xcodeproj`를 열어 실행합니다.
- 현재 단계는 `목데이터 기반 SwiftUI 프로토타입`이며, 실제 API 연동은 포함하지 않습니다.
