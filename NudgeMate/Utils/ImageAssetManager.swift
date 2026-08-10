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

    var systemName: String {
        switch self {
        case .calendar:
            "calendar"
        case .reminder:
            "bell.badge.fill"
        case .empty:
            "tray.fill"
        case .refresh:
            "arrow.triangle.2.circlepath"
        case .success:
            "checkmark.circle.fill"
        case .pro:
            "crown.fill"
        case .privacy:
            "lock.shield.fill"
        case let .category(category):
            category.systemSymbolName
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
            ColorTheme.accentSky.opacity(0.15)
        case .success:
            ColorTheme.success.opacity(0.15)
        case .pro:
            ColorTheme.proAccent.opacity(0.16)
        case let .category(category):
            category.symbolTint.opacity(0.15)
        }
    }
}

struct NudgeSymbolImage: View {
    let symbol: NudgeSymbol
    let pointSize: CGFloat

    var body: some View {
        Image(systemName: symbol.systemName)
            .font(.system(size: pointSize, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(symbol.tint)
            .accessibilityHidden(true)
    }
}

struct NudgeSymbolBadge: View {
    let symbol: NudgeSymbol
    let size: CGFloat

    var body: some View {
        NudgeSymbolImage(symbol: symbol, pointSize: size * 0.45)
            .frame(width: size, height: size)
            .background(
                symbol.background,
                in: RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

extension RhythmCategory {
    var systemSymbolName: String {
        switch self {
        case .personalCare:
            "sparkles"
        case .health:
            "heart.fill"
        case .vehicle:
            "car.fill"
        case .home:
            "house.fill"
        case .pet:
            "pawprint.fill"
        case .finance:
            "creditcard.fill"
        case .work:
            "briefcase.fill"
        case .other:
            "square.grid.2x2.fill"
        }
    }

    var symbolTint: Color {
        switch self {
        case .personalCare:
            ColorTheme.accentLavender
        case .health:
            ColorTheme.accentCoral
        case .vehicle:
            ColorTheme.accentSky
        case .home:
            ColorTheme.accentAmber
        case .pet:
            ColorTheme.accentLavender
        case .finance:
            ColorTheme.success
        case .work:
            ColorTheme.primaryNudge
        case .other:
            ColorTheme.secondaryText
        }
    }
}
