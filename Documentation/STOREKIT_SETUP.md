# StoreKit 2 설정

## 상품 ID

- `com.nudgemate.pro.monthly`: 자동 갱신 월간
- `com.nudgemate.pro.yearly`: 자동 갱신 연간
- `com.nudgemate.pro.lifetime`: 비소모성 평생 이용권

월간과 연간은 App Store Connect에서 같은 구독 그룹에 둔다. `NudgeMate.storekit`은 로컬 가격과 상품 유형을 제공하며 Tuist의 `NudgeMate` 스킴에 연결되어 있다.

## App Store Connect

1. Bundle ID `com.nudgemate.app`에 In-App Purchase capability를 활성화한다.
2. 위 상품을 생성하고 가격, 판매 지역, 심사 스크린샷, 현지화 설명을 입력한다.
3. Paid Applications 계약과 세금·은행 정보를 완료한다.
4. Sandbox 계정으로 구매, 갱신, 만료, 취소, Ask to Buy, 복원을 확인한다.

앱은 검증된 `Transaction.currentEntitlements`와 `Transaction.updates`만 신뢰한다. 실제 App Store 가격을 표시하며 가격 문자열을 코드에 하드코딩하지 않는다.
