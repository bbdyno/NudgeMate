# 위젯과 Live Activity

## 제품 목표

위젯은 앱을 열기 전에 가장 가까운 준비 일정을 한눈에 확인하는 표면이다. Live Activity는 사용자가 실제로 준비를 시작한 짧은 구간을 잠금 화면과 Dynamic Island에서 이어 주는 표면이다. 둘 다 새로운 작업 관리 기능을 만들지 않고 기존 `EventPrep`의 상태와 다음 행동을 반영한다.

## 사용자 흐름

1. 준비 일정을 만들거나 수정하면 홈 화면·잠금 화면 위젯 스냅샷이 갱신된다.
2. 위젯은 목표일이 지나지 않았고 완료되지 않은 준비 중 가장 가까운 최대 3개를 표시한다.
3. 위젯을 누르면 `nudgemate://prep/{id}`로 해당 준비 화면을 연다.
4. 준비 카드에서 상태를 `진행 중`으로 선택하면 사용자의 명시적 행동을 계기로 Live Activity가 시작된다.
5. 상태·제목·목표 시각·다음 행동을 수정하면 기존 Live Activity를 갱신한다.
6. `준비 전`, `준비 완료`, 삭제 또는 목표일 경과 시 Live Activity를 종료한다.

## 지원 화면

- 홈 화면: 작은 위젯, 중간 위젯
- 잠금 화면: 인라인, 원형, 직사각형 위젯
- Live Activity: 잠금 화면, Dynamic Island 최소·컴팩트·확장 화면

## 디자인 원칙

- 크림 배경과 라벤더 구조색, 임박 상태의 코랄 강조색을 앱과 동일하게 사용한다.
- 작은 화면에는 `D-day`, 제목, 상태만 남기고 다음 행동은 중간 위젯과 Live Activity에서 보여준다.
- 시스템 타이머를 사용해 화면을 다시 그리지 않아도 남은 시간이 갱신되게 한다.
- 빈 위젯은 샘플 데이터를 가장하지 않고 준비 추가를 안내한다.
- 위젯 전체를 해당 준비의 딥 링크로 연결하고 최소 44pt 앱 내 상태 컨트롤은 그대로 유지한다.

## 기술 설계

```text
SwiftData EventPrep
    ↓ 저장/상태 변경/삭제/포그라운드 동기화
WidgetActivityCoordinator
    ├─ App Group JSON snapshot → WidgetKit timeline reload
    └─ ActivityKit request/update/end → Live Activity UI
```

- 앱 Bundle ID: `com.bbdyno.app.nudgemate`
- 위젯 확장 Bundle ID: `com.bbdyno.app.nudgemate.widget`
- App Group: `group.com.bbdyno.app.nudgemate`
- 공유 모델은 `NudgeMateShared`를 앱과 확장에 각각 컴파일한다.
- 위젯에는 제목, 목표일, 상태, 사용자가 입력한 다음 행동만 최대 3개 저장한다. 캘린더 식별자, 원본 일정, 구매 정보는 공유하지 않는다. 잠금 화면 개인정보 설정이 일반 문구이면 제목과 다음 행동은 App Group 및 ActivityKit 상태에 기록하지 않는다. ActivityKit의 4KB 제한을 안정적으로 지키도록 공유 제목은 80자, 다음 행동은 160자로 제한한다.
- 서버와 APNs 없이 앱 프로세스에서만 Live Activity를 갱신한다. 앱이 실행되지 않는 동안에는 시스템 타이머만 계속 갱신된다.
- Live Activity는 시스템 정책상 최대 8시간 활성화되며, 이후 잠금 화면에 최대 4시간 더 남을 수 있다. 장기 준비 전체가 아니라 현재 준비 세션을 보조하는 기능으로 정의한다.

## 개발자 계정 설정

1. Apple Developer에서 앱 ID `com.bbdyno.app.nudgemate`를 등록한다.
2. 확장 ID `com.bbdyno.app.nudgemate.widget`를 등록한다.
3. App Group `group.com.bbdyno.app.nudgemate`를 등록한다.
4. 앱 ID와 확장 ID 양쪽에 같은 App Group을 연결한다.
5. 새 프로비저닝 프로파일을 발급하거나 Xcode 자동 서명이 갱신하게 한다.

## 수동 QA

- 빈 상태와 준비 1개·3개 이상일 때 작은/중간 위젯
- 목표일 자정 경계, 당일, 완료, 경과 일정 필터링
- 위젯 딥 링크가 해당 준비 편집 화면을 여는지 확인
- `진행 중` 선택 시 Live Activity 시작, 내용 수정 시 갱신, 다른 상태·삭제 시 종료
- Dynamic Island 지원/미지원 기기, Always-On Display, 다크 모드
- 한국어·영어·중국어 간체·번체·일본어와 긴 제목
- Live Activities 시스템 설정이 꺼진 경우 앱의 상태 변경이 정상 저장되는지 확인
- 전체 데이터 삭제 시 위젯과 Live Activity가 즉시 정리되는지 확인
