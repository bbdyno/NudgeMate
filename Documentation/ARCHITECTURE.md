# 아키텍처

## 계층

- `App`: 조립, 전역 화면 상태, 앱 생명주기
- `Core/Domain`: 프레임워크와 분리된 값 타입과 상태
- `Core/NudgeEngine`, `Core/PrepEngine`: 결정적 계산 로직
- `Core/Calendar`, `Core/Notifications`: 시스템 프레임워크 프로토콜과 구현
- `Core/Persistence`: SwiftData 스키마, 마이그레이션, 저장소
- `NudgeMateShared`: 앱과 위젯 확장이 함께 컴파일하는 최소 공유 데이터 계약
- `NudgeMateWidgets`: WidgetKit 타임라인, 잠금 화면 위젯, ActivityKit 표시 UI
- `Managers`: 기능 조정과 비동기 작업
- `Views`, `ViewModels`: SwiftUI 화면과 사용자 의도 처리

UI 상태는 Observation의 `@Observable`, 영속 데이터는 SwiftData `@Model`, 시스템 I/O는 `async/await`를 사용한다. EventKit 객체는 actor 밖으로 전달하지 않고 즉시 `CalendarEventSnapshot`으로 변환한다.

`WidgetActivityCoordinator`는 SwiftData 변경을 App Group의 제한된 JSON 스냅샷으로 투영하고 WidgetKit 타임라인을 다시 불러온다. 위젯 확장은 SwiftData 컨테이너를 직접 열지 않는다. Live Activity의 생성·갱신·종료는 앱에서 ActivityKit으로 수행하고 UI만 위젯 확장에 둔다.

## 데이터 안전

SwiftData 컨테이너 생성 실패는 오류 화면으로 전환하며 강제 종료하지 않는다. 앱은 캘린더 원문 전체를 복제하지 않고 승인된 리듬의 날짜와 제한된 출처 식별자만 저장한다.
