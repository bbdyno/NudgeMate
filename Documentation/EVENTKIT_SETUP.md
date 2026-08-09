# EventKit 설정

`NSCalendarsFullAccessUsageDescription`은 `Project.swift`와 각 언어의 `InfoPlist.strings`에 정의되어 있다. 권한 팝업은 온보딩 설명 뒤 사용자가 “캘린더에서 리듬 찾기”를 선택할 때만 요청한다.

캘린더 목록은 소스별로 표시하며 생일, 공휴일, 구독, 읽기 전용 캘린더를 기본 제외한다. 사용자가 다시 선택할 수 있다. 스캔 기본 범위는 과거 12개월이고 서비스 API는 최대 24개월을 허용한다.

일정 추가는 쓰기 가능한 선택 캘린더 또는 시스템 기본 캘린더를 사용한다. notes의 UUID marker로 재시도 시 중복 생성을 막는다. 실제 기기 QA에서는 권한 허용·거부·설정 변경과 로컬/iCloud/Exchange 캘린더를 각각 확인한다.
