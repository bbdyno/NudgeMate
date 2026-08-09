import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct MainTabView: View {
    enum Tab: CaseIterable {
        case today
        case rhythms
        case prep

        var title: String {
            switch self {
            case .today: L10n.Tab.today
            case .rhythms: L10n.Tab.rhythms
            case .prep: L10n.Tab.prep
            }
        }

        var asset: ImageAssetManager.Asset {
            switch self {
            case .today: .nudgeAlert
            case .rhythms: .sync
            case .prep: .calendarIcon
            }
        }
    }

    @Environment(AppState.self) private var appState
    @State private var selection: Tab = .today

    var body: some View {
        ZStack {
            switch selection {
            case .today:
                HomeView()
            case .rhythms:
                RhythmListView()
            case .prep:
                PrepListView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 8) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                            selection = tab
                        }
                    } label: {
                        VStack(spacing: 3) {
                            SVGAssetImage(asset: tab.asset)
                                .frame(width: 25, height: 25)
                                .accessibilityHidden(true)
                            Text(tab.title)
                                .pretendard(.caption2, weight: selection == tab ? .bold : .medium)
                        }
                        .foregroundStyle(selection == tab ? ColorTheme.primaryNudge : ColorTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
            .background(.bar)
            .overlay(alignment: .top) {
                Divider()
            }
            .accessibilityIdentifier("main.tabbar")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dailyRecapRequested)) { _ in
            appState.isDailyRecapPresented = true
        }
    }
}
