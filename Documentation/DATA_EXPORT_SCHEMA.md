# 데이터 내보내기 스키마

파일명은 `NudgeMate-yyyy-MM-dd-HHmmss.json`, 인코딩은 UTF-8, 날짜는 ISO 8601이다.

최상위 필드:

- `formatVersion`: 현재 1
- `exportedAt`: 생성 시각
- `rhythms`: 이름, 분류, 방식, 간격, 변동, 신뢰도, 날짜 기록, 다음 예상 기간, 상태
- `preparations`: 제목, 목표일, 준비 상태, 빈도, 다음 행동, 다음 알림, 상태
- `settings`: 선택 캘린더 식별자, Recap, 개인정보 알림, 화면 테마
- `suppressedPatterns`: 제외 서명과 제외 만료일

캘린더 원본 이벤트 본문, 참석자, 메모, 위치, StoreKit 거래 정보는 포함하지 않는다. 향후 필드 변경 시 `formatVersion`을 올리고 기존 필드를 임의로 재해석하지 않는다.
