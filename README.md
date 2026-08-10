<p align="center">
  <img src="Website/assets/nudgemate-journey.png" alt="NudgeMate가 일정의 리듬을 따라 다음 순간을 미리 발견하는 종이 공예 풍경" width="100%">
</p>

<h1 align="center">NudgeMate</h1>

<p align="center">
  반복되는 일, 늦기 전에.<br>
  캘린더의 리듬을 발견하고 다음 일정과 중요한 준비를 미리 챙기는 iOS 앱입니다.
</p>

<p align="center">
  <a href="https://bbdyno.github.io/NudgeMate/">Website</a>
  ·
  <a href="Documentation/PRODUCT_SPEC.md">Product spec</a>
  ·
  <a href="Documentation/RELEASE_CHECKLIST.md">Release checklist</a>
</p>

NudgeMate는 과거 일정의 간격을 분석해 다음 시점을 예상하고, 중요한 일정은 준비 상태에 따라 다시 확인하는 iOS 17+ 개인 일정 도우미입니다. 캘린더 분석과 학습 데이터는 기기에서 처리합니다.

## 실행

요구 환경은 Xcode 15 이상, Swift 5.9, Tuist 4입니다.

```sh
tuist generate
open NudgeMate.xcworkspace
```

`NudgeMate` 스킴에는 `NudgeMate/Resources/NudgeMate.storekit`이 연결되어 있어 시뮬레이터에서 월간·연간·평생 상품을 시험할 수 있습니다.

## 구현 범위

- SwiftUI + Observation MVVM + SwiftData
- EventKit 전체 접근 교육, 캘린더 선택, 최근 12개월 분석, 후보 승인·수정·제외
- 중앙값·MAD 기반 리듬 예측과 D-3 로컬 알림
- 준비 상태별 간격 계산, 대화형 알림, Daily Recap
- StoreKit 2 구매·복원·거래 관찰과 무료 한도
- JSON 데이터 내보내기 및 전체 앱 데이터 삭제
- 한국어, 영어, 중국어 간체·번체, 일본어 TuistStrings 현지화
- Pretendard Dynamic Type 및 자체 SVG/앱 아이콘 자산

## 외부 설정

- App Store Connect에서 코드와 동일한 상품 ID를 생성한다.
- 배포 전 `NudgeMatePrivacyPolicyURL` Info.plist 키에 실제 공개 개인정보처리방침 HTTPS URL을 설정한다.
- Signing & Capabilities에서 배포 Team을 지정한다.

세부 설계와 출시 절차는 `Documentation/`에 정리되어 있습니다.

## 홍보 사이트

`Website/`는 별도 빌드 과정 없이 동작하는 정적 GitHub Pages 사이트입니다. 한국어, 영어, 중국어 간체·번체, 일본어를 지원하며 브라우저 언어를 자동 감지합니다.

```sh
python3 -m http.server 8080 --directory Website
```

처음 한 번 저장소의 **Settings → Pages → Source**를 **GitHub Actions**로 지정해야 합니다. 이후 `main` 브랜치의 `Website/` 또는 Pages 워크플로가 변경되면 GitHub Actions가 사이트를 배포합니다.
