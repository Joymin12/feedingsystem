# iOS 프로토타입

## 목표

- Xcode에서 열어 실제 아이폰에 설치 가능한 SwiftUI 프로토타입 제공
- 첫 단계는 `전체 탭형`, `목데이터 기반`, `사용성 검증용`에 집중

## 실행 방법

1. Xcode에서 `HanwooPrototype.xcodeproj`를 연다.
2. `Signing & Capabilities`에서 본인 Apple ID Team을 선택한다.
3. 실행 대상 디바이스를 `iPhone` 또는 `iOS Simulator`로 고른다.
4. `Run`으로 설치한다.

## 현재 포함 범위

- 로그인
- 회원가입
- 사육 단계 선택
- 홈
- 배합
- 최근 분석
- 사육일지
- 커뮤니티
- 내 농장

## 현재 제외 범위

- 실 API 연동
- 실제 AI 호출
- 서버 저장
- 푸시, TestFlight, 파일 내보내기
