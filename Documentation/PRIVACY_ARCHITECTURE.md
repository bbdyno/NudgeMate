# 개인정보 보호 구조

- 캘린더 분석은 EventKit과 앱 프로세스 안에서 수행한다.
- 캘린더·리듬·준비 데이터는 외부 백엔드나 Google Mobile Ads에 전달하지 않는다.
- 무료 사용자에게만 Google Mobile Ads 13.8.0과 User Messaging Platform 3.1.0을 사용한다. Pro 사용자는 SDK 시작과 광고 요청을 건너뛴다.
- UMP 동의 정보 갱신은 온보딩을 마친 무료 사용자의 앱 실행마다 수행하며, `canRequestAds`가 참일 때만 광고 SDK를 시작한다.
- 전면 광고는 Daily Recap을 완료한 뒤에만 시도하고 로컬·서버 양쪽에서 24시간 빈도 제한을 적용한다.
- 전체 캘린더 원문을 SwiftData에 복제하지 않는다.
- 로그에 일정 제목, 위치, 참석자를 남기지 않는다.
- 잠금 화면 알림은 상세 또는 일반 문구를 사용자가 선택한다.
- 위젯 App Group에는 완료되지 않은 준비 최대 3개의 ID, 제목, 목표일, 상태, 다음 행동만 저장한다.
- Live Activity는 같은 최소 준비 정보만 사용하며 외부 네트워크나 위치 정보에 접근하지 않는다.
- 사용자는 JSON 내보내기와 전체 앱 데이터 삭제를 실행할 수 있다.
- 전체 삭제는 로컬 모델, 예약 알림, 위젯 스냅샷과 Live Activity를 제거하지만 App Store 구매 권한은 제거하지 않는다.

개인정보처리방침 URL은 `NudgeMatePrivacyPolicyURL` Info.plist 키로 관리한다. 설정의 개인정보 선택은 UMP가 요구하는 지역에서 동의 옵션을 다시 연다.

앱 자체 Privacy Manifest는 앱이 직접 접근하는 API를 선언하고, Google SDK의 데이터 수집·추적 선언은 각 프레임워크의 Privacy Manifest에 포함된다. 출시 전 Archive의 통합 Privacy Report와 `Documentation/APP_PRIVACY_ANSWERS.md`를 다시 대조한다.
