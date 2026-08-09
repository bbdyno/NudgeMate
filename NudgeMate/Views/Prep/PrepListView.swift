import SwiftData
import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct PrepListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \EventPrep.targetDate)
    private var preps: [EventPrep]

    @State private var editingPrep: EventPrep?
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if preps.isEmpty {
                    EmptyStateView(
                        icon: .calendarIcon,
                        title: L10n.Prep.Empty.title,
                        message: L10n.Prep.Empty.message,
                        actionTitle: L10n.Prep.add
                    ) {
                        isCreating = true
                    }
                } else {
                    List {
                        ForEach(preps) { prep in
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    editingPrep = prep
                                } label: {
                                    PrepRow(prep: prep)
                                }
                                .buttonStyle(.plain)

                                if prep.status != .ready && prep.targetDate >= .now {
                                    Picker(L10n.Prep.readiness, selection: statusBinding(for: prep)) {
                                        ForEach(PrepStatus.allCases, id: \.self) { status in
                                            Text(status.localizedTitle).tag(status)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                            .padding(.vertical, 5)
                            .swipeActions {
                                Button(L10n.Common.delete, role: .destructive) {
                                    delete(prep)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(ColorTheme.background)
            .navigationTitle(L10n.Prep.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.Prep.add) { isCreating = true }
                        .pretendard(.headline, weight: .semibold)
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            PrepEditorView(prep: nil)
                .environment(appState)
        }
        .sheet(item: $editingPrep) { prep in
            PrepEditorView(prep: prep)
                .environment(appState)
        }
        .alert(L10n.Common.error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.Common.confirm, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func statusBinding(for prep: EventPrep) -> Binding<PrepStatus> {
        Binding(
            get: { prep.status },
            set: { status in
                Task {
                    do {
                        try await appState.nudgeManager.updatePrep(
                            prep,
                            status: status,
                            modelContext: modelContext
                        )
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        )
    }

    private func delete(_ prep: EventPrep) {
        appState.nudgeManager.cancelPrepReminder(for: prep.id)
        modelContext.delete(prep)
        do { try modelContext.save() } catch { errorMessage = error.localizedDescription }
    }
}

private struct PrepRow: View {
    let prep: EventPrep

    private var daysRemaining: Int {
        Calendar.autoupdatingCurrent.dateComponents(
            [.day],
            from: Calendar.autoupdatingCurrent.startOfDay(for: .now),
            to: Calendar.autoupdatingCurrent.startOfDay(for: prep.targetDate)
        ).day ?? 0
    }

    var body: some View {
        HStack(spacing: 14) {
            SVGAssetImage(asset: .calendarIcon)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(prep.title)
                    .pretendard(.headline, weight: .semibold)
                    .foregroundStyle(ColorTheme.primaryText)
                Text(L10n.Prep.Row.detail(
                    daysRemaining,
                    prep.targetDate.formatted(date: .abbreviated, time: .omitted)
                ))
                .pretendard(.subheadline)
                .foregroundStyle(ColorTheme.secondaryText)
                if !prep.nextActionNote.isEmpty {
                    Text(prep.nextActionNote)
                        .pretendard(.caption)
                        .foregroundStyle(ColorTheme.secondarySnooze)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PrepEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let prep: EventPrep?

    @State private var title: String
    @State private var targetDate: Date
    @State private var intensity: PrepIntensity
    @State private var nextAction: String
    @State private var notificationsEnabled: Bool
    @State private var errorMessage: String?

    @Query private var allPreps: [EventPrep]

    init(prep: EventPrep?) {
        self.prep = prep
        _title = State(initialValue: prep?.title ?? "")
        _targetDate = State(initialValue: prep?.targetDate ?? Calendar.autoupdatingCurrent.date(byAdding: .day, value: 14, to: .now) ?? .now)
        _intensity = State(initialValue: prep?.intensity ?? .normal)
        _nextAction = State(initialValue: prep?.nextActionNote ?? "")
        _notificationsEnabled = State(initialValue: prep?.notificationsEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Prep.Editor.basic) {
                    TextField(L10n.Prep.Editor.title, text: $title)
                    DatePicker(
                        L10n.Prep.Editor.targetDate,
                        selection: $targetDate,
                        in: Date.now...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField(L10n.Prep.Editor.nextAction, text: $nextAction, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(L10n.Prep.Editor.reminder) {
                    Picker(L10n.Prep.Editor.intensity, selection: $intensity) {
                        Text(L10n.Prep.Intensity.low).tag(PrepIntensity.low)
                        Text(L10n.Prep.Intensity.normal).tag(PrepIntensity.normal)
                        Text(L10n.Prep.Intensity.high).tag(PrepIntensity.high)
                    }
                    Toggle(L10n.Rhythm.Editor.notifications, isOn: $notificationsEnabled)
                        .tint(ColorTheme.primaryNudge)
                }
            }
            .pretendard(.body)
            .navigationTitle(prep == nil ? L10n.Prep.Editor.newTitle : L10n.Prep.Editor.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save, action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .alert(L10n.Common.error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.Common.confirm, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        let activePrepCount = allPreps.filter {
            $0.planState == .active && $0.id != prep?.id
        }.count
        if EntitlementPolicy().prepCreation(
            activePrepCount: activePrepCount,
            isPro: appState.subscriptionManager.isPro
        ) == .requiresPro {
            appState.presentPaywall()
            return
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let schedule = PrepScheduleCalculator(calendar: .autoupdatingCurrent).nextCheckIn(
            now: .now,
            targetDate: targetDate,
            status: prep?.status.readinessStatus ?? .notReady,
            intensity: intensity
        )
        let nextDate: Date = switch schedule {
        case let .scheduled(date), let .finalCheck(date): date
        case .stopped, .targetPassed: targetDate
        }
        let value = prep ?? EventPrep(
            title: trimmedTitle,
            targetDate: targetDate,
            nextReminderDate: nextDate
        )
        value.title = trimmedTitle
        value.targetDate = targetDate
        value.intensity = intensity
        value.nextActionNote = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        value.nextReminderDate = nextDate
        value.notificationsEnabled = notificationsEnabled
        value.updatedAt = .now

        if prep == nil { modelContext.insert(value) }
        do {
            try modelContext.save()
            if notificationsEnabled && value.status != .ready {
                Task { try? await appState.nudgeManager.schedulePrepReminder(for: value) }
            } else {
                appState.nudgeManager.cancelPrepReminder(for: value.id)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
