# 폰트 설정

`NudgeMate/Resources/Fonts`에 Pretendard Regular, Medium, SemiBold, Bold와 SIL Open Font License가 포함되어 있다. `Project.swift`의 `UIAppFonts`에 파일명을 등록한다.

`TypographyManager`는 각 SwiftUI 텍스트 스타일에 `Font.custom(_:size:relativeTo:)`를 적용하므로 Dynamic Type 배율을 유지한다. 폰트 파일을 교체할 때 PostScript 이름과 등록 파일명이 일치하는지 실제 기기에서 확인한다.
