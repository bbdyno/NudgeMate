import EventKit
import SwiftData
import SwiftUI
import UIKit

private typealias L10n = NudgeMateStrings.Localizable

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var settings: UserSettings?
    @State private var calendarState: CalendarAuthorizationState = .notDetermined
    @State private var notificationState: NotificationPermissionState = .notDetermined
    @State private var exportURL: URL?
    @State private var isCalendarFlowPresented = false
    @State private var isPrivacyInfoPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                notificationSection
                recapSection
                appearanceSection
                proSection
                privacySection
                dataSection
                aboutSection
            }
            .pretendard(.body)
            .nudgeFormStyle()
            .navigationTitle(L10n.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
        }
        .task { load() }
        .fullScreenCover(isPresented: $isCalendarFlowPresented) {
            CalendarDiscoveryFlowView {
                isCalendarFlowPresented = false
                load()
            }
            .environment(appState)
        }
        .sheet(isPresented: $isPrivacyInfoPresented) {
            PrivacyInformationView()
        }
        .sheet(isPresented: Binding(
            get: { exportURL != nil },
            set: { if !$0 { exportURL = nil } }
        )) {
            NavigationStack {
                VStack(spacing: 22) {
                    NudgeSymbolBadge(symbol: .success, size: 96)
                    Text(L10n.Settings.Export.ready)
                        .pretendard(.title2, weight: .bold)
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Text(L10n.Settings.Export.share)
                                .pretendard(.headline, weight: .semibold)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(NudgePrimaryButtonStyle())
                    }
                }
                .padding(24)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.Common.done) { exportURL = nil }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            L10n.Settings.Delete.title,
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.Settings.Delete.confirm, role: .destructive) {
                deleteAllData()
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Settings.Delete.message)
        }
        .alert(L10n.Common.error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.Common.confirm, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(L10n.App.name, isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button(L10n.Common.confirm, role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private var accountSection: some View {
        Section(L10n.Settings.Sync.title) {
            SettingsCalendarConnectionRow(
                status: calendarStatusText,
                isConnected: calendarState == .fullAccess
            )
            Button(L10n.Settings.Sync.chooseCalendars) {
                if calendarState == .fullAccess {
                    isCalendarFlowPresented = true
                } else {
                    Task { await requestCalendarAccess() }
                }
            }
            Button(L10n.Settings.Sync.openSystemSettings) {
                openSystemSettings()
            }
        }
    }

    private var notificationSection: some View {
        Section(L10n.Settings.Notification.title) {
            LabeledContent(
                L10n.Settings.Notification.status,
                value: notificationStatusText
            )
            Button(L10n.Settings.Notification.request) {
                Task {
                    do {
                        try await appState.nudgeManager.requestAuthorization()
                        notificationState = .authorized
                        if let settings {
                            await appState.nudgeManager.reconcileAll(settings: settings)
                        }
                        statusMessage = L10n.Settings.Notification.authorizedMessage
                    } catch {
                        notificationState = await appState.nudgeManager.refreshAuthorizationState()
                        errorMessage = error.localizedDescription
                    }
                }
            }
            if settings != nil {
                Picker(
                    L10n.Settings.Notification.privacyMode,
                    selection: settingBinding(\.privacyNotificationMode, fallback: .detailed)
                ) {
                    Text(L10n.Settings.Notification.detailed).tag(PrivacyNotificationMode.detailed)
                    Text(L10n.Settings.Notification.generic).tag(PrivacyNotificationMode.generic)
                }
            }
        }
    }

    private var recapSection: some View {
        Section(L10n.Settings.Recap.title) {
            if let settings {
                Toggle(
                    L10n.Settings.Recap.enabled,
                    isOn: settingBinding(\.dailyRecapEnabled, fallback: true)
                )
                    .tint(ColorTheme.primaryNudge)
                DatePicker(
                    L10n.Settings.Recap.time,
                    selection: recapTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .disabled(!settings.dailyRecapEnabled)
                Picker(
                    L10n.Settings.Recap.frequency,
                    selection: settingBinding(\.dailyRecapFrequency, fallback: .daily)
                ) {
                    Text(L10n.Settings.Recap.daily).tag(DailyRecapFrequency.daily)
                    Text(L10n.Settings.Recap.threeTimes).tag(DailyRecapFrequency.threeTimesWeekly)
                    Text(L10n.Settings.Recap.weekly).tag(DailyRecapFrequency.weekly)
                    Text(L10n.Settings.Recap.off).tag(DailyRecapFrequency.off)
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section(L10n.Settings.Appearance.title) {
            if settings != nil {
                Picker(L10n.Settings.Appearance.theme, selection: appearanceBinding) {
                    Text(L10n.Settings.Appearance.system).tag(AppearanceTheme.system)
                    Text(L10n.Settings.Appearance.light).tag(AppearanceTheme.light)
                    Text(L10n.Settings.Appearance.dark).tag(AppearanceTheme.dark)
                    Text(L10n.Settings.Appearance.pro).tag(AppearanceTheme.pro)
                }
            }
        }
    }

    private var proSection: some View {
        Section {
            Button {
                appState.presentPaywall()
            } label: {
                HStack(spacing: 14) {
                    NudgeSymbolBadge(symbol: .pro, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.subscriptionManager.isPro ? L10n.Settings.Pro.active : L10n.Settings.Pro.title)
                            .pretendard(.headline, weight: .bold)
                            .foregroundStyle(ColorTheme.primaryText)
                        Text(L10n.Settings.Pro.message)
                            .pretendard(.caption)
                            .foregroundStyle(ColorTheme.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var privacySection: some View {
        Section(L10n.Settings.Privacy.title) {
            Button(L10n.Settings.Privacy.explanation) {
                isPrivacyInfoPresented = true
            }
            Text(L10n.Settings.Privacy.Ads.explanation)
                .foregroundStyle(ColorTheme.secondaryText)
            if !appState.subscriptionManager.isPro,
               appState.adMobManager.privacyOptionsRequired {
                Button(L10n.Settings.Privacy.Ads.choices) {
                    Task {
                        do {
                            try await appState.adMobManager.presentPrivacyOptions()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            if let url = AppConfiguration.adReportURL {
                Link(L10n.Settings.Privacy.Ads.report, destination: url)
            }
            if let url = AppConfiguration.privacyPolicyURL {
                Link(L10n.Paywall.privacy, destination: url)
            }
        }
    }

    private var dataSection: some View {
        Section(L10n.Settings.Data.title) {
            Button(L10n.Settings.Export.action) {
                do {
                    exportURL = try DataPrivacyManager().makeExportFile(modelContext: modelContext)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            Button(L10n.Settings.Delete.action, role: .destructive) {
                isDeleteConfirmationPresented = true
            }
        }
    }

    private var aboutSection: some View {
        Section(L10n.Settings.About.title) {
            LabeledContent(L10n.Settings.About.version, value: versionText)
            if let url = AppConfiguration.termsOfServiceURL {
                Link(L10n.Paywall.terms, destination: url)
            }
        }
    }

    private var calendarStatusText: String {
        switch calendarState {
        case .fullAccess: L10n.Settings.Sync.connected
        case .denied, .restricted: L10n.Settings.Sync.denied
        case .writeOnly: L10n.Settings.Sync.writeOnly
        case .notDetermined: L10n.Settings.Sync.notConnected
        }
    }

    private var notificationStatusText: String {
        switch notificationState {
        case .authorized: L10n.Settings.Notification.authorized
        case .denied: L10n.Settings.Notification.denied
        case .notDetermined: L10n.Settings.Notification.notDetermined
        }
    }

    private var recapTimeBinding: Binding<Date> {
        Binding(
            get: {
                guard let settings else { return .now }
                return Calendar.autoupdatingCurrent.date(
                    bySettingHour: settings.dailyRecapHour,
                    minute: settings.dailyRecapMinute,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                guard var value = settings else { return }
                let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
                value.dailyRecapHour = components.hour ?? 22
                value.dailyRecapMinute = components.minute ?? 0
                save(value)
            }
        )
    }

    private var appearanceBinding: Binding<AppearanceTheme> {
        Binding(
            get: { settings?.appearanceTheme ?? .system },
            set: { theme in
                if theme == .pro && !appState.subscriptionManager.isPro {
                    appState.presentPaywall()
                    return
                }
                guard var value = settings else { return }
                value.appearanceTheme = theme
                save(value)
            }
        )
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (\(build))"
    }

    private func settingBinding<Value>(
        _ keyPath: WritableKeyPath<UserSettings, Value>,
        fallback: Value
    ) -> Binding<Value> {
        Binding(
            get: { settings?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                guard var value = settings else { return }
                value[keyPath: keyPath] = newValue
                save(value)
            }
        )
    }

    private func load() {
        do {
            settings = try SwiftDataSettingsRepository(context: modelContext).load()
        } catch {
            errorMessage = error.localizedDescription
        }
        Task {
            await appState.eventKitManager.refreshAuthorizationState()
            calendarState = appState.eventKitManager.authorizationState
            notificationState = await appState.nudgeManager.refreshAuthorizationState()
        }
    }

    private func save(_ value: UserSettings) {
        var updated = value
        updated.updatedAt = .now
        do {
            try SwiftDataSettingsRepository(context: modelContext).save(updated)
            settings = updated
            appState.updateSettings(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestCalendarAccess() async {
        do {
            try await appState.eventKitManager.requestAccess()
            calendarState = appState.eventKitManager.authorizationState
            if calendarState == .fullAccess { isCalendarFlowPresented = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func deleteAllData() {
        Task {
            await appState.nudgeManager.cancelAll()
            do {
                try DataPrivacyManager().deleteAllData(modelContext: modelContext)
                await appState.nudgeManager.clearWidgetsAndActivities()
                appState.resetAfterDataDeletion()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct SettingsCalendarConnectionRow: View {
    let status: String
    let isConnected: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                calendarLabel
                Spacer(minLength: 8)
                statusLabel
            }

            VStack(alignment: .leading, spacing: 8) {
                calendarLabel
                statusLabel
                    .padding(.leading, 38)
            }
        }
    }

    private var calendarLabel: some View {
        Label {
            Text(L10n.Settings.Sync.appleCalendar)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            NudgeSymbolBadge(symbol: .calendar, size: 28)
        }
    }

    private var statusLabel: some View {
        Text(status)
            .foregroundStyle(isConnected ? ColorTheme.success : ColorTheme.secondaryText)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct PrivacyInformationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    NudgeSymbolBadge(symbol: .privacy, size: 108)
                        .frame(maxWidth: .infinity)
                    Text(L10n.Settings.Privacy.Info.title)
                        .pretendard(.title2, weight: .bold)
                    privacyItem(L10n.Settings.Privacy.Info.localTitle, L10n.Settings.Privacy.Info.localMessage)
                    privacyItem(L10n.Settings.Privacy.Info.calendarTitle, L10n.Settings.Privacy.Info.calendarMessage)
                    privacyItem(L10n.Settings.Privacy.Info.adsTitle, L10n.Settings.Privacy.Info.adsMessage)
                    privacyItem(L10n.Settings.Privacy.Info.controlTitle, L10n.Settings.Privacy.Info.controlMessage)
                }
                .padding(24)
            }
            .background(NudgeScreenBackground())
            .navigationTitle(L10n.Settings.Privacy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
        }
    }

    private func privacyItem(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).pretendard(.headline, weight: .semibold)
            Text(message).pretendard(.body).foregroundStyle(ColorTheme.secondaryText)
        }
    }
}
