# Supabase Auth/Community Setup

이 프로젝트에서 Supabase는 아래 범위만 담당합니다.

- 회원가입 / 로그인 / 로그아웃
- 사용자 프로필
- 사용자별 원료 선택
- 커뮤니티 글 작성 / 조회 / 삭제

배합 계산과 복합교정 엔진은 계속 iOS 로컬에서 돌립니다.

## 앱 설정

Xcode 타깃 `HanwooPrototype`의 Info.plist 생성 빌드 설정에 아래 두 값을 넣습니다.

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

현재 프로젝트에는 두 키가 비어 있으면 로컬 fallback을 유지하고, 값이 들어가면 Supabase 모드로 전환되도록 되어 있습니다.

## 필수 SQL

아래 파일을 Supabase SQL Editor에서 실행합니다.

- `/Users/jowm/Desktop/feedingsystem/docs/supabase/schema.sql`

이 스키마가 만드는 것:

- `profiles`
- `user_ingredients`
- `community_posts`
- 신규 auth user 생성 시 profile 자동 생성 트리거
- RLS 정책

## 앱 동작 방식

### 회원가입

1. 사용자가 이메일/비밀번호/원료 목록을 입력
2. 앱이 Supabase Auth `signUp` 호출
3. 원료 목록은 `raw_user_meta_data.selected_ingredient_ids`로 같이 보냄
4. 이메일 인증이 켜져 있으면 세션 없이 종료
5. 사용자가 메일 인증 후 로그인
6. 첫 로그인 시 앱이 profile을 upsert하고, `user_ingredients`가 비어 있으면 metadata 기반으로 채움

### 로그인

1. 앱이 이메일/비밀번호로 `auth/v1/token?grant_type=password` 호출
2. access token / refresh token 저장
3. `auth/v1/user`로 현재 사용자 조회
4. `profiles`, `user_ingredients`, `community_posts`를 불러옴

### 커뮤니티

- 조회: 전체 공개
- 작성: 로그인 사용자만
- 삭제: 작성자 본인 또는 `profiles.is_admin = true`

## 현재 구현 제약

- Supabase 모드에서는 로그인 입력값을 이메일로 봅니다.
- 과거 로컬 관리자 계정 `qwer123 / asdf123` 흐름은 Supabase 모드에서 사용하지 않습니다.
- 진짜 운영에서는 관리자도 이메일 기반 계정으로 두고 `profiles.is_admin = true`만 부여하는 게 맞습니다.

## 관리자 계정 부여

관리자 사용자를 만들려면:

1. 일반 이메일 회원가입으로 계정 생성
2. Supabase SQL Editor에서 아래 실행

```sql
update public.profiles
set is_admin = true
where email = 'admin@example.com';
```

## 개발자에게 전달할 핵심

먼저 읽을 문서:

- `/Users/jowm/Desktop/feedingsystem/docs/tmr-recommendation-engine-developer-brief.md`
- `/Users/jowm/Desktop/feedingsystem/docs/supabase/supabase-auth-community-setup.md`
- `/Users/jowm/Desktop/feedingsystem/docs/supabase/schema.sql`

구현 원칙:

- 배합 계산 엔진은 로컬 유지
- 사용자 계정과 커뮤니티만 Supabase로 이동
- 사용자별 원료 선택은 `user_ingredients`에서 제어
- 추천안은 여전히 로컬 계산 엔진이 생성
