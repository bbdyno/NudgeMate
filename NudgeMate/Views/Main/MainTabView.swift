import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct MainTabView: View {
    enum Tab: CaseIterable, Hashable {
        case today
        case rhythms
        case prep
        case more

        var title: String {
            switch self {
            case .today: L10n.Tab.today
            case .rhythms: L10n.Tab.rhythms
            case .prep: L10n.Tab.prep
            case .more: L10n.Common.moreActions
            }
        }

        var iconAsset: String {
            switch self {
            case .today: "glyph_tab_today"
            case .rhythms: "glyph_tab_rhythms"
            case .prep: "glyph_tab_prep"
            case .more: "glyph_tab_more"
            }
        }

        var identifier: String {
            switch self {
            case .today: "today"
            case .rhythms: "rhythms"
            case .prep: "prep"
            case .more: "more"
            }
        }
    }

    @Environment(AppState.self) private var appState
    @State private var selection: Tab
    @State private var isQuickAddPresented = false
    @State private var quickAddEditorDestination: QuickAddEditorDestination?
    @State private var confirmationMessage: String?

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Tab
        if arguments.contains("--open-rhythms") {
            initialTab = .rhythms
        } else if arguments.contains("--open-prep") {
            initialTab = .prep
        } else if arguments.contains("--open-more") {
            initialTab = .more
        } else {
            initialTab = .today
        }
        _selection = State(initialValue: initialTab)
        _isQuickAddPresented = State(initialValue: arguments.contains("--open-quick-add"))
    }

    var body: some View {
        NudgeSelectedTabContent(selection: selection)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NudgeMainTabBar(selection: $selection) {
                isQuickAddPresented = true
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .sensoryFeedback(.impact(weight: .medium), trigger: isQuickAddPresented)
        .overlay {
            if isQuickAddPresented {
                QuickAddOverlay(
                    onDismiss: dismissQuickAdd,
                    onSelect: openQuickAddEditor
                )
                .transition(.opacity)
            }
        }
        .fullScreenCover(item: $quickAddEditorDestination) { destination in
            quickAddEditorSheet(for: destination)
        }
        .alert(L10n.App.name, isPresented: confirmationBinding) {
            Button(L10n.Common.confirm) { confirmationMessage = nil }
        } message: {
            Text(confirmationMessage ?? "")
        }
        .task { route(appState.pendingNavigation) }
        .onChange(of: appState.pendingNavigation) { _, destination in
            route(destination)
        }
    }

    @ViewBuilder
    private func quickAddEditorSheet(for destination: QuickAddEditorDestination) -> some View {
        switch destination {
        case .calendarEvent:
            CalendarEventComposerView(
                draft: CalendarEventComposerDraft(startDate: nextAvailableHour())
            ) { title in
                confirmationMessage = L10n.Home.calendarAdded(title)
            }
            .environment(appState)
        case .prep:
            PrepEditorView(prep: nil)
                .environment(appState)
        }
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmationMessage != nil },
            set: { if !$0 { confirmationMessage = nil } }
        )
    }

    private func dismissQuickAdd() {
        withAnimation(.easeOut(duration: 0.18)) {
            isQuickAddPresented = false
        }
    }

    private func openQuickAddEditor(_ destination: QuickAddEditorDestination) {
        dismissQuickAdd()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            quickAddEditorDestination = destination
        }
    }

    private func nextAvailableHour(from date: Date = .now) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let startOfHour = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        return calendar.date(byAdding: .hour, value: 1, to: startOfHour)
            ?? date.addingTimeInterval(3_600)
    }

    private func route(_ destination: AppNavigationDestination?) {
        guard let destination else { return }
        switch destination {
        case .today:
            selection = .today
            appState.consumeNavigation(destination)
        case .rhythms:
            selection = .rhythms
            appState.consumeNavigation(destination)
        case .rhythm:
            selection = .rhythms
        case .scheduleRhythm:
            selection = .today
        case .preps:
            selection = .prep
            appState.consumeNavigation(destination)
        case .prep:
            selection = .prep
        case .recap:
            selection = .today
            appState.isDailyRecapPresented = true
            appState.consumeNavigation(destination)
        }
    }
}

private struct NudgeSelectedTabContent: View {
    let selection: MainTabView.Tab

    var body: some View {
        switch selection {
        case .today:
            HomeView()
        case .rhythms:
            RhythmListView()
        case .prep:
            PrepListView()
        case .more:
            MoreView()
        }
    }
}

private struct MoreView: View {
    @Environment(AppState.self) private var appState
    @State private var isSettingsPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                NudgeScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(L10n.Common.moreActions)
                            .pretendard(.largeTitle, weight: .bold)
                            .foregroundStyle(ColorTheme.primaryText)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            MoreMenuRow(
                                assetName: "glyph_settings",
                                title: L10n.Settings.title,
                                subtitle: L10n.Settings.Sync.title,
                                accessibilityIdentifier: "more.settings"
                            ) {
                                isSettingsPresented = true
                            }

                            MoreMenuDivider()

                            MoreMenuRow(
                                assetName: "glyph_reminder",
                                title: L10n.Settings.Recap.title,
                                subtitle: L10n.Settings.Recap.enabled,
                                accessibilityIdentifier: "more.recap"
                            ) {
                                isSettingsPresented = true
                            }

                            MoreMenuDivider()

                            MoreMenuRow(
                                assetName: "glyph_privacy",
                                title: L10n.Settings.Privacy.title,
                                subtitle: L10n.Settings.Privacy.explanation,
                                accessibilityIdentifier: "more.privacy"
                            ) {
                                isSettingsPresented = true
                            }
                        }
                        .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(ColorTheme.separator, lineWidth: 1)
                        }

                        Button {
                            appState.presentPaywall()
                        } label: {
                            HStack(spacing: 14) {
                                NudgeSymbolBadge(symbol: .pro, size: 48)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.Settings.Pro.title)
                                        .pretendard(.headline, weight: .bold)
                                        .foregroundStyle(ColorTheme.primaryText)
                                    Text(L10n.Settings.Pro.message)
                                        .pretendard(.caption)
                                        .foregroundStyle(ColorTheme.secondaryText)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 8)
                                NudgeAssetIcon(name: "glyph_disclosure", size: 16)
                                    .foregroundStyle(ColorTheme.primaryNudge)
                            }
                            .padding(16)
                            .background(ColorTheme.brandSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("more.pro")
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, NudgeLayoutMetrics.listBottomClearance)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("more.screen")
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environment(appState)
        }
    }
}

private struct MoreMenuRow: View {
    let assetName: String
    let title: String
    let subtitle: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NudgeAssetIcon(name: assetName, size: 20)
                    .foregroundStyle(ColorTheme.primaryNudge)
                    .frame(width: 42, height: 42)
                    .background(ColorTheme.brandSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .pretendard(.subheadline, weight: .bold)
                        .foregroundStyle(ColorTheme.primaryText)
                    Text(subtitle)
                        .pretendard(.caption2)
                        .foregroundStyle(ColorTheme.secondaryText)
                }

                Spacer(minLength: 8)

                NudgeAssetIcon(name: "glyph_disclosure", size: 15)
                    .foregroundStyle(ColorTheme.secondaryText.opacity(0.65))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct MoreMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(ColorTheme.separator)
            .frame(height: 1)
            .padding(.leading, 69)
    }
}

private enum QuickAddEditorDestination: String, Identifiable, Equatable {
    case calendarEvent
    case prep

    var id: String { rawValue }
}

private struct QuickAddOverlay: View {
    let onDismiss: () -> Void
    let onSelect: (QuickAddEditorDestination) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ColorTheme.primaryText.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            QuickAddChooser(onDismiss: onDismiss, onSelect: onSelect)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("quickAdd.chooser")
    }
}

private struct QuickAddChooser: View {
    let onDismiss: () -> Void
    let onSelect: (QuickAddEditorDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Common.add)
                        .pretendard(.title2, weight: .bold)
                        .foregroundStyle(ColorTheme.primaryText)
                    Text(L10n.QuickCapture.subtitle)
                        .pretendard(.caption)
                        .foregroundStyle(ColorTheme.secondaryText)
                }

                Spacer(minLength: 8)

                Button(action: onDismiss) {
                    NudgeCloseMark()
                        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .foregroundStyle(ColorTheme.secondaryText)
                        .frame(width: 13, height: 13)
                        .frame(width: 36, height: 36)
                        .background(ColorTheme.background, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Common.cancel)
            }

            HStack(spacing: 12) {
                QuickAddChoice(
                    title: L10n.Calendar.Composer.newTitle,
                    subtitle: L10n.Calendar.Composer.startDate,
                    symbol: .calendar,
                    accessibilityIdentifier: "quickAdd.calendar"
                ) {
                    choose(.calendarEvent)
                }

                QuickAddChoice(
                    title: L10n.Prep.Editor.newTitle,
                    subtitle: L10n.Prep.Editor.targetDate,
                    symbol: .reminder,
                    accessibilityIdentifier: "quickAdd.prep"
                ) {
                    choose(.prep)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.86), lineWidth: 1)
        }
        .shadow(color: ColorTheme.primaryText.opacity(0.13), radius: 24, y: 10)
    }

    private func choose(_ destination: QuickAddEditorDestination) {
        withAnimation(.easeInOut(duration: 0.2)) {
            onSelect(destination)
        }
    }
}

private struct NudgeCloseMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

private struct QuickAddChoice: View {
    let title: String
    let subtitle: String
    let symbol: NudgeSymbol
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                NudgeSymbolBadge(symbol: symbol, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .pretendard(.subheadline, weight: .bold)
                        .foregroundStyle(ColorTheme.primaryText)
                    Text(subtitle)
                        .pretendard(.caption2)
                        .foregroundStyle(ColorTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .padding(14)
            .background(ColorTheme.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ColorTheme.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct NudgeMainTabBar: View {
    @Binding var selection: MainTabView.Tab
    let onQuickAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            NudgeMainTabButton(tab: .today, selection: $selection)
            NudgeMainTabButton(tab: .rhythms, selection: $selection)

            NudgeQuickAddButton(action: onQuickAdd)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            NudgeMainTabButton(tab: .prep, selection: $selection)
            NudgeMainTabButton(tab: .more, selection: $selection)
        }
        .padding(.horizontal, 7)
        .frame(height: 74)
        .background {
            Capsule(style: .continuous)
                .fill(ColorTheme.tabBarBackdrop)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(ColorTheme.separator.opacity(0.92), lineWidth: 1)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("main.tabbar")
    }
}

private struct NudgeMainTabButton: View {
    let tab: MainTabView.Tab
    @Binding var selection: MainTabView.Tab

    var body: some View {
        let isSelected = selection == tab

        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(ColorTheme.brandSoft)
                            .frame(width: 38, height: 31)
                    }

                    NudgeAssetIcon(name: tab.iconAsset, size: 23)
                        .foregroundStyle(isSelected ? ColorTheme.primaryNudge : ColorTheme.secondaryText.opacity(0.52))
                }
                .frame(height: 31)

                Text(tab.title)
                    .pretendard(.caption2, weight: isSelected ? .bold : .medium)
                    .foregroundStyle(isSelected ? ColorTheme.primaryNudge : ColorTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("main.tab.\(tab.identifier)")
    }
}

private struct NudgeQuickAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NudgePlusMark()
                .fill(Color.white)
                .frame(width: 19, height: 19)
                .frame(width: 52, height: 52)
                .background(ColorTheme.accentCoral, in: Circle())
                .overlay {
                    Circle()
                        .stroke(ColorTheme.cardBackground, lineWidth: 3)
                }
                .shadow(color: ColorTheme.accentCoral.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Common.add)
        .accessibilityIdentifier("main.quickAdd")
    }
}

private struct NudgePlusMark: Shape {
    func path(in rect: CGRect) -> Path {
        let thickness = min(rect.width, rect.height) * 0.16
        var path = Path()
        path.addRoundedRect(
            in: CGRect(
                x: rect.midX - thickness / 2,
                y: rect.minY,
                width: thickness,
                height: rect.height
            ),
            cornerSize: CGSize(width: thickness / 2, height: thickness / 2)
        )
        path.addRoundedRect(
            in: CGRect(
                x: rect.minX,
                y: rect.midY - thickness / 2,
                width: rect.width,
                height: thickness
            ),
            cornerSize: CGSize(width: thickness / 2, height: thickness / 2)
        )
        return path
    }
}
