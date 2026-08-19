# 출시 체크리스트

## 코드와 프로젝트

- [x] `tuist generate` 성공
- [ ] Debug/Release 시뮬레이터 빌드 성공
- [x] 단위 테스트 실제 실행 및 결과 기록
- [ ] UI 테스트 실제 실행 및 결과 기록
- [ ] 주요 경로의 warning, 강제 종료, 미완성 placeholder 없음
- [ ] iOS 17 최소 지원과 iPhone/iPad 레이아웃 확인
- [x] 앱 `com.bbdyno.app.nudgemate`, 확장 `com.bbdyno.app.nudgemate.widget` 서명 확인

## 계정과 상품

- [x] Apple Developer Team과 배포 인증서 지정
- [ ] App Store Connect 월간·연간·평생 상품 생성 및 심사 정보 입력
- [ ] 구독 그룹, 가격, 판매 지역, 현지화 확인
- [ ] Sandbox 실기기 구매·복원·만료 확인
- [x] App Group `group.com.bbdyno.app.nudgemate` 등록 및 앱·확장 양쪽 연결

## 개인정보와 법무

- [x] 실제 HTTPS 개인정보처리방침 게시
- [x] `NudgeMatePrivacyPolicyURL` Info.plist 값 설정
- [x] UMP 유럽 규정 메시지 게시 상태와 개인정보 선택 재호출 확인
- [x] Archive의 앱·Google SDK Privacy Manifest를 App Privacy 답변과 대조
- [x] 추적 데이터의 기기 ID와 광고 SDK 데이터 유형을 App Store Connect에 신고
- [x] ATT를 사용하지 않는 현재 빌드에 `NSUserTrackingUsageDescription`이 없는지 확인
- [ ] 표준 EULA 또는 별도 이용약관 결정
- [x] App Privacy 답변을 제출 빌드와 재대조
- [ ] Pretendard SIL OFL과 앱 Apache 2.0 고지 확인

## 광고와 수익화

- [x] AdMob 앱 ID `ca-app-pub-8965771939775493~6712972291` 확인
- [x] Daily Recap 전면 광고 ID `ca-app-pub-8965771939775493/7478475235` 확인
- [x] Debug 빌드는 Google 테스트 광고 ID, Release 빌드는 운영 광고 ID를 사용하는지 확인
- [x] 무료 사용자에게 Daily Recap 완료 후 최대 24시간에 한 번만 노출되는지 확인
- [x] Pro 사용자에게 UMP 요청, 광고 SDK 시작, 광고 로드와 노출이 없는지 확인
- [x] `bbdyno/bbdyno.github.io` 저장소의 루트 `app-ads.txt`와 `https://bbdyno.github.io/app-ads.txt` 응답 확인
- [x] AdMob 앱 인증을 완료한 뒤 앱 준비 상태가 `준비됨`인지 확인
- [x] 광고 로드 실패·동의 거부·오프라인 상태에서도 Recap 완료 흐름이 막히지 않는지 확인

## 기능 QA

- [ ] 캘린더 권한 허용·거부·설정 복구
- [ ] 로컬/iCloud/Exchange 캘린더 선택과 스캔
- [ ] 후보 승인·수정·제외, 리듬 생성·편집·삭제
- [ ] 준비 3상태와 목표일 경과
- [ ] 알림 액션, 중복 방지, Daily Recap 시간·빈도
- [ ] JSON 내보내기와 전체 삭제
- [ ] 작은·중간·잠금 화면 위젯의 빈 상태, 정렬, 딥 링크
- [ ] Live Activity 시작·갱신·종료와 Dynamic Island 3개 표시 모드
- [ ] 한국어·영어·중국어 간체·번체·일본어
- [ ] 다크 모드, VoiceOver, 최대 Dynamic Type, Reduce Motion

## 스토어 자료

- [ ] 모든 기기 크기의 스크린샷과 앱 미리보기
- [x] 앱 설명, 키워드, 지원 URL, 개인정보 URL
- [ ] 앱 아이콘과 연령 등급
- [x] 심사 메모에 캘린더 권한 목적과 StoreKit 테스트 경로 설명
