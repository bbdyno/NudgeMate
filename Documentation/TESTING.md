# 테스트

## 명령

```sh
tuist generate --no-open
xcodebuild -workspace NudgeMate.xcworkspace -scheme NudgeMate -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcodebuild -workspace NudgeMate.xcworkspace -scheme NudgeMate -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

단위 테스트는 제목 정규화, 유사도, 중앙값·이상치, 예상 기간, 준비 간격, 무료 한도, 후보 스캔, 10,000건 blocking 성능, StoreKit 상품 구성을 다룬다. UI smoke test는 첫 실행 온보딩을 확인한다.

수동 QA에는 권한 거부/복구, 캘린더 종류, 알림 액션의 종료 상태 처리, 시간대·DST, 다크 모드, 가장 큰 Dynamic Type, VoiceOver, Reduce Motion, 구매 성공/취소/대기/복원/만료를 포함한다.

문서에 기록하는 통과 수는 실제 실행 결과만 사용한다. 상품 구매 최종 검증은 Sandbox 실기기에서도 수행한다.
