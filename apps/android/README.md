# Android App

`apps/android`는 Kotlin + Jetpack Compose 기반 안드로이드 클라이언트입니다.

## 화면 구성

- 홈
- 배합 입력
- AI 추천 결과
- 커뮤니티
- 농장 설정

## API 연결

Android Emulator에서는 호스트 PC의 Nest API를 `http://10.0.2.2:4000`으로 호출합니다.

## 주의사항

- JDK 17이 필요합니다.
- Android Studio에서 프로젝트를 열어 Gradle Sync 해야 합니다.
- 현재 레포에는 Gradle wrapper가 없어서 Android Studio 기준으로 초기 sync를 수행하는 흐름을 가정합니다.