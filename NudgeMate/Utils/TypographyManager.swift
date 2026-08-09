import SwiftUI

enum AppTypographyStyle: CaseIterable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption
    case caption2

    fileprivate var metrics: (size: CGFloat, relativeTo: Font.TextStyle) {
        switch self {
        case .largeTitle: return (34, .largeTitle)
        case .title: return (28, .title)
        case .title2: return (22, .title2)
        case .title3: return (20, .title3)
        case .headline: return (17, .headline)
        case .body: return (17, .body)
        case .callout: return (16, .callout)
        case .subheadline: return (15, .subheadline)
        case .footnote: return (13, .footnote)
        case .caption: return (12, .caption)
        case .caption2: return (11, .caption2)
        }
    }
}

enum PretendardWeight {
    case regular
    case medium
    case semibold
    case bold

    fileprivate var fontName: String {
        switch self {
        case .regular: return "Pretendard-Regular"
        case .medium: return "Pretendard-Medium"
        case .semibold: return "Pretendard-SemiBold"
        case .bold: return "Pretendard-Bold"
        }
    }
}

enum TypographyManager {
    static func font(
        for style: AppTypographyStyle,
        weight: PretendardWeight = .regular
    ) -> Font {
        let metrics = style.metrics
        return .custom(
            weight.fontName,
            size: metrics.size,
            relativeTo: metrics.relativeTo
        )
    }
}

private struct PretendardTypographyModifier: ViewModifier {
    let style: AppTypographyStyle
    let weight: PretendardWeight

    func body(content: Content) -> some View {
        content.font(TypographyManager.font(for: style, weight: weight))
    }
}

extension View {
    func pretendard(
        _ style: AppTypographyStyle,
        weight: PretendardWeight = .regular
    ) -> some View {
        modifier(PretendardTypographyModifier(style: style, weight: weight))
    }
}
