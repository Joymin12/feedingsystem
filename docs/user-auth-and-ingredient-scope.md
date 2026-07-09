# User Auth And Ingredient Scope

## 현재 기준

이 앱의 현재 운영 기준은 `로컬 저장 우선`이다.

역할 분리:

- `iOS 로컬`
  - 회원가입
  - 로그인 / 로그아웃
  - 사용자 프로필
  - 사용자별 원료 선택
  - 커뮤니티 글 저장 / 삭제
  - 배합 입력
  - 영양 계산
  - 복합교정안 추천
  - 사육일지 / 최근 분석
- `Supabase`
  - 현재 미사용
  - 추후 원격 인증/커뮤니티 전환 시 참고용 코드와 문서만 유지

## 사용자 정책

- 일반 사용자는 이메일로 가입한다.
- 회원가입 시 자신이 사용하는 원료를 선택할 수 있다.
- 회원가입에서만 `건너뛰기`가 가능하다.
- 사용자가 원료를 선택하면 배합 화면의 원료 추가 목록에서 해당 원료만 보인다.
- 건너뛰면 전체 원료를 본다.

## 저장 구조

### 로컬 저장

- `AppUser`
  - `loginID`
  - `email`
  - `password`
  - `farmName`
  - `preferredStage`
  - `selectedIngredientIDs`
  - `isAdmin`
- `CommunityPost`
  - `id`
  - `authorLoginID`
  - `title`
  - `excerpt`
  - `label`
  - `createdAt`

### Supabase fallback 코드

Supabase 설정이 비어 있으면 로컬 저장만 사용한다. 현재 릴리즈 경로에서는 이 상태를 기본으로 본다.

## 인증 흐름

### 로그인

- 이메일 또는 관리자 아이디
- 비밀번호

### 회원가입

- 입력값
  - 이메일
  - 비밀번호
  - 비밀번호 재확인
  - 자신의 원료 선택
- 이메일 인증은 현재 로컬 인증코드 생성 방식 유지

## 커뮤니티 권한

- 일반 사용자
  - 글 작성 가능
  - 자신이 쓴 글만 삭제 가능
- 관리자
  - 모든 글 삭제 가능

현재는 로컬 사용자의 `isAdmin = true`로 판정한다.

## 관련 코드 파일

- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/HanwooPrototypeApp.swift`
- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/SupabaseService.swift`
- `/Users/jowm/Desktop/feedingsystem/docs/supabase/supabase-auth-community-setup.md`

## 현재 한계

- 현재 관리자 계정 `qwer123 / asdf123`은 로컬 하드코딩 상태다.
- 비밀번호와 커뮤니티 저장은 로컬 저장이라 실제 출시 전에는 보안/동기화 재검토가 필요하다.
- 배합 계산 엔진은 여전히 로컬이다. 이것은 의도된 구조다.
