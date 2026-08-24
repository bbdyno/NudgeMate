# NudgeMate 1.2.0 출시 상태

- 마케팅 버전: `1.2.0`
- 빌드 번호: `2026082401`
- 기준일: 2026-08-24

## 완료

- AdMob 앱 인증 `확인됨`, 승인 상태 `준비됨`
- AdMob 정책 센터에 광고 게재 제한 또는 정책 위반 없음
- Daily Recap 전면 광고 단위에 사용자별 `24시간당 1회` 게재빈도 설정 확인
- NudgeMate 유럽 규정 동의 메시지 `게시됨` 확인
- `https://bbdyno.github.io/app-ads.txt`의 게시자 선언과 HTTP 200 응답 확인
- Tuist 4.203.1 프로젝트 생성 성공
- iPhone 17 Pro / iOS 26.5에서 단위 테스트 66개와 UI 테스트 12개, 총 78개 통과
- Release 시뮬레이터 빌드 성공 및 산출물에서 ATT 프레임워크 링크, 빌드 번호, 5개 언어 권한 문구 확인
- Release 기기 Archive와 앱·위젯 App Group 서명 확인
- Archive에서 Google Mobile Ads 및 UMP Privacy Manifest 확인
- Release Info.plist에 운영 AdMob 앱 ID, 개인정보처리방침 URL, 현지화된 `NSUserTrackingUsageDescription`이 포함됨
- 기존 App Store 배포용 IPA 빌드 `2026081901`은 ATT 미구현으로 리젝됨
- 수정 빌드 `2026082401` 업로드 성공 및 TestFlight `Ready to Submit` 처리 완료 확인
- App Privacy에 Google SDK Privacy Manifest 기준 7개 데이터 유형과 기기 ID 추적 사용 게시
- App Store `1.2.0` 버전에 수정 빌드 `2026082401` 연결 완료
- 한국어, 영어(미국), 중국어 간체·번체, 일본어 설명·프로모션 문구·릴리스 노트 갱신
- 심사 메모에 무료 광고 노출 조건, UMP, Pro 광고 제외, ATT 위치와 거부 시 동작 반영
- AdMob IDFA 설명 메시지를 NudgeMate와 5개 언어 대상으로 게시
- 신규 설치 무료 사용자 경로에서 `Google UMP IDFA 설명 → iOS ATT → 사용자 선택 → 광고 요청` 순서를 실제 확인
- ATT 거부 후 홈, Add 화면, 재실행 정상 동작과 권한 화면 비반복 확인
- App Review에 수정 내용과 재현 경로 답변 전송
- 수정 빌드 재제출 완료, App Review 상태 `Waiting for Review`

## 최초 App Review 제출

- 제출 시각: 2026-08-19 12:24 KST
- 제출 ID: `d0e2465f-8530-4635-8151-bad75a68ddcf`
- 제출 항목: iOS App `1.2.0 (2026081901)`
- 출시 방식: 심사 승인 후 자동 출시, 모든 사용자에게 즉시 제공
- 리젝 일시: 2026-08-21 10:07 KST
- 리젝 사유: App Privacy에서 기기 ID 추적을 신고했으나 ATT 권한 요청이 없음

## 참고

- 업로드 시 GoogleMobileAds 및 UserMessagingPlatform 프레임워크의 공급사 dSYM 누락 경고가 있었으나 업로드와 처리에는 성공했습니다. 패키지 배포물에도 해당 dSYM이 없어 현재 제출을 막는 항목은 아닙니다.
- 신규 설치 실기동 검증은 iPhone 17 Pro / iOS 26.5 시뮬레이터에서 `--ui-testing` 없이 수행했습니다. ATT 요청은 13:22:27 KST, 거부 확정은 13:22:36 KST, 최초 광고 요청은 13:22:37 KST로 기록되어 광고 요청 전 동의 순서를 확인했습니다.
- 재제출 시각: 2026-08-24 13:28 KST
- 제출 ID: `d0e2465f-8530-4635-8151-bad75a68ddcf`
- 제출 항목: iOS App `1.2.0 (2026082401)`
- 출시 방식: 심사 승인 후 자동 출시, 모든 사용자에게 즉시 제공
