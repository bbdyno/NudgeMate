import SwiftUI

enum ArtworkAsset: String {
    case paywallHero = "paywall_hero"
}

struct ArtworkAssetImage: View {
    let asset: ArtworkAsset

    var body: some View {
        Image(asset.rawValue)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
    }
}

enum NudgeSymbol {
    case calendar
    case reminder
    case empty
    case refresh
    case success
    case pro
    case privacy
    case category(RhythmCategory)

    var assetName: String {
        switch self {
        case .calendar:
            "glyph_calendar"
        case .reminder:
            "glyph_reminder"
        case .empty:
            "glyph_empty"
        case .refresh:
            "glyph_tab_rhythms"
        case .success:
            "glyph_success"
        case .pro:
            "glyph_pro"
        case .privacy:
            "glyph_privacy"
        case let .category(category):
            category.iconAssetName
        }
    }

    var tint: Color {
        switch self {
        case .calendar:
            ColorTheme.accentLavender
        case .reminder:
            ColorTheme.secondarySnooze
        case .empty:
            ColorTheme.secondaryText
        case .refresh:
            ColorTheme.accentSky
        case .success:
            ColorTheme.success
        case .pro:
            ColorTheme.proAccent
        case .privacy:
            ColorTheme.primaryNudge
        case let .category(category):
            category.symbolTint
        }
    }

    var background: Color {
        switch self {
        case .calendar, .privacy:
            ColorTheme.brandSoft
        case .reminder:
            ColorTheme.selectionFill
        case .empty:
            ColorTheme.backgroundDeep
        case .refresh:
            ColorTheme.brandSoft
        case .success:
            ColorTheme.success.opacity(0.15)
        case .pro:
            ColorTheme.proAccent.opacity(0.16)
        case let .category(category):
            category == .health
                ? ColorTheme.selectionFill
                : ColorTheme.brandSoft
        }
    }
}

struct NudgeAssetIcon: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct NudgeSymbolImage: View {
    let symbol: NudgeSymbol
    let pointSize: CGFloat

    var body: some View {
        NudgeAssetIcon(name: symbol.assetName, size: pointSize)
            .foregroundStyle(symbol.tint)
            .accessibilityHidden(true)
    }
}

struct NudgeSymbolBadge: View {
    let symbol: NudgeSymbol
    let size: CGFloat

    var body: some View {
        NudgeSymbolImage(symbol: symbol, pointSize: size * 0.53)
            .frame(width: size, height: size)
            .background(
                symbol.background,
                in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
            )
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .stroke(symbol.tint.opacity(0.08), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

extension RhythmCategory {
    var iconAssetName: String {
        switch self {
        case .personalCare:
            "glyph_personal_care"
        case .health:
            "glyph_health"
        case .vehicle:
            "glyph_vehicle"
        case .home:
            "glyph_home"
        case .pet:
            "glyph_pet"
        case .finance:
            "glyph_finance"
        case .work:
            "glyph_work"
        case .other:
            "glyph_other"
        }
    }

    var symbolTint: Color {
        switch self {
        case .personalCare:
            ColorTheme.primaryNudge
        case .health:
            ColorTheme.accentCoral
        case .vehicle:
            ColorTheme.primaryNudge
        case .home:
            ColorTheme.primaryNudge
        case .pet:
            ColorTheme.primaryNudge
        case .finance:
            ColorTheme.primaryNudge
        case .work:
            ColorTheme.primaryNudge
        case .other:
            ColorTheme.primaryNudge
        }
    }
}
