import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct MainTabView: View {
    enum Tab: CaseIterable, Hashable {
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

        var systemImage: String {
            switch self {
            case .today: "sun.max.fill"
            case .rhythms: "repeat"
            case .prep: "checklist"
            }
        }

        var identifier: String {
            switch self {
            case .today: "today"
            case .rhythms: "rhythms"
            case .prep: "prep"
            }
        }
    }

    @Environment(AppState.self) private var appState
    @State private var selection: Tab

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Tab
        if arguments.contains("--open-rhythms") {
            initialTab = .rhythms
        } else if arguments.contains("--open-prep") {
            initialTab = .prep
        } else {
            initialTab = .today
        }
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tag(tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                        .accessibilityIdentifier("main.tab.\(tab.identifier)")
                    }
            }
        }
        .tint(ColorTheme.primaryNudge)
        .toolbarBackground(.automatic, for: .tabBar)
        .task { route(appState.pendingNavigation) }
        .onChange(of: appState.pendingNavigation) { _, destination in
            route(destination)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .today:
            HomeView()
        case .rhythms:
            RhythmListView()
        case .prep:
            PrepListView()
        }
    }

    private func route(_ destination: AppNavigationDestination?) {
        guard let destination else { return }
        switch destination {
        case .today:
            selection = .today
            appState.consumeNavigation(destination)
        case .rhythm:
            selection = .rhythms
        case .scheduleRhythm:
            selection = .today
        case .prep:
            selection = .prep
        case .recap:
            selection = .today
            appState.isDailyRecapPresented = true
            appState.consumeNavigation(destination)
        }
    }
}
