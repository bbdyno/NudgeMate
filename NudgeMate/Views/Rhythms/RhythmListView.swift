import SwiftData
import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct RhythmListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \RecurringEvent.nextExpectedCenterDate)
    private var rhythms: [RecurringEvent]

    @State private var editingRhythm: RecurringEvent?
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if rhythms.isEmpty {
                    EmptyStateView(
                        icon: .sync,
                        title: L10n.Rhythm.Empty.title,
                        message: L10n.Rhythm.Empty.message,
                        actionTitle: L10n.Rhythm.add
                    ) {
                        isCreating = true
                    }
                } else {
                    List {
                        ForEach(rhythms) { rhythm in
                            Button {
                                editingRhythm = rhythm
                            } label: {
                                RhythmRow(rhythm: rhythm)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(L10n.Common.delete, role: .destructive) {
                                    delete(rhythm)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(rhythm.isMuted ? L10n.Rhythm.resume : L10n.Rhythm.pause) {
                                    toggle(rhythm)
                                }
                                .tint(ColorTheme.secondarySnooze)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(ColorTheme.background)
            .navigationTitle(L10n.Rhythm.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.Rhythm.add) { isCreating = true }
                        .pretendard(.headline, weight: .semibold)
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            RhythmEditorView(rhythm: nil)
                .environment(appState)
        }
        .sheet(item: $editingRhythm) { rhythm in
            RhythmEditorView(rhythm: rhythm)
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

    private func toggle(_ rhythm: RecurringEvent) {
        rhythm.isMuted.toggle()
        rhythm.updatedAt = .now
        do {
            try modelContext.save()
            if rhythm.isMuted {
                appState.nudgeManager.cancelNudge(for: rhythm.id)
            } else {
                Task { try? await appState.nudgeManager.scheduleNudge(for: rhythm) }
            }
        } catch {
            rhythm.isMuted.toggle()
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ rhythm: RecurringEvent) {
        appState.nudgeManager.cancelNudge(for: rhythm.id)
        modelContext.delete(rhythm)
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RhythmRow: View {
    let rhythm: RecurringEvent

    var body: some View {
        HStack(spacing: 14) {
            SVGAssetImage(asset: .sync)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(rhythm.displayName)
                        .pretendard(.headline, weight: .semibold)
                        .foregroundStyle(ColorTheme.primaryText)
                    if rhythm.isMuted {
                        Text(L10n.Rhythm.paused)
                            .pretendard(.caption2, weight: .semibold)
                            .foregroundStyle(ColorTheme.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(ColorTheme.progressTrack, in: Capsule())
                    }
                }
                Text(L10n.Rhythm.Row.detail(
                    rhythm.baseIntervalDays,
                    rhythm.nextExpectedCenterDate.formatted(date: .abbreviated, time: .omitted)
                ))
                .pretendard(.subheadline)
                .foregroundStyle(ColorTheme.secondaryText)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct RhythmEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let rhythm: RecurringEvent?

    @State private var name: String
    @State private var category: RhythmCategory
    @State private var mode: RhythmMode
    @State private var intervalDays: Int
    @State private var lastOccurrence: Date
    @State private var leadTimeDays: Int
    @State private var notificationsEnabled: Bool
    @State private var errorMessage: String?

    @Query private var allRhythms: [RecurringEvent]

    init(rhythm: RecurringEvent?) {
        self.rhythm = rhythm
        _name = State(initialValue: rhythm?.displayName ?? "")
        _category = State(initialValue: rhythm?.category ?? .other)
        _mode = State(initialValue: rhythm?.mode ?? .fixed)
        _intervalDays = State(initialValue: rhythm?.baseIntervalDays ?? 30)
        _lastOccurrence = State(initialValue: rhythm?.lastOccurrenceDate ?? .now)
        _leadTimeDays = State(initialValue: rhythm?.leadTimeDays ?? 3)
        _notificationsEnabled = State(initialValue: rhythm?.notificationsEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Rhythm.Editor.basic) {
                    TextField(L10n.Rhythm.Editor.name, text: $name)
                    Picker(L10n.Candidate.category, selection: $category) {
                        ForEach(RhythmCategory.allCases, id: \.self) { value in
                            Text(categoryTitle(value)).tag(value)
                        }
                    }
                    Picker(L10n.Rhythm.Editor.mode, selection: $mode) {
                        Text(L10n.Rhythm.Editor.fixed).tag(RhythmMode.fixed)
                        Text(L10n.Rhythm.Editor.adaptive).tag(RhythmMode.adaptive)
                    }
                }

                Section(L10n.Rhythm.Editor.schedule) {
                    Stepper(L10n.Rhythm.Editor.interval(intervalDays), value: $intervalDays, in: 1...365)
                    DatePicker(L10n.Rhythm.Editor.lastDate, selection: $lastOccurrence, displayedComponents: .date)
                    Stepper(L10n.Rhythm.Editor.leadTime(leadTimeDays), value: $leadTimeDays, in: 0...30)
                    Toggle(L10n.Rhythm.Editor.notifications, isOn: $notificationsEnabled)
                        .tint(ColorTheme.primaryNudge)
                }
            }
            .pretendard(.body)
            .navigationTitle(rhythm == nil ? L10n.Rhythm.Editor.newTitle : L10n.Rhythm.Editor.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save, action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        let activeAdaptiveCount = allRhythms.filter {
            $0.mode == .adaptive && $0.lifecycleState == .active && $0.id != rhythm?.id
        }.count
        if mode == .adaptive,
           EntitlementPolicy().adaptiveRhythmCreation(
               activeAdaptiveCount: activeAdaptiveCount,
               isPro: appState.subscriptionManager.isPro
           ) == .requiresPro {
            appState.presentPaywall()
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let center = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: intervalDays,
            to: lastOccurrence
        ) ?? lastOccurrence.addingTimeInterval(TimeInterval(intervalDays * 86_400))
        let value = rhythm ?? RecurringEvent(
            title: trimmedName,
            baseInterval: intervalDays,
            historyDates: [lastOccurrence],
            nextPredictedDate: center
        )
        value.displayName = trimmedName
        value.normalizedName = EventNormalizer().normalize(trimmedName)
        value.category = category
        value.mode = mode
        value.origin = rhythm?.origin ?? .manual
        value.baseIntervalDays = intervalDays
        value.lastOccurrenceDate = lastOccurrence
        if !value.historyDates.contains(where: { Calendar.autoupdatingCurrent.isDate($0, inSameDayAs: lastOccurrence) }) {
            value.historyDates.append(lastOccurrence)
        }
        value.nextPredictedDate = center
        value.leadTimeDays = leadTimeDays
        value.notificationsEnabled = notificationsEnabled
        value.lifecycleState = notificationsEnabled ? .active : .paused
        value.updatedAt = .now

        if rhythm == nil { modelContext.insert(value) }
        do {
            try modelContext.save()
            if notificationsEnabled {
                Task { try? await appState.nudgeManager.scheduleNudge(for: value) }
            } else {
                appState.nudgeManager.cancelNudge(for: value.id)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func categoryTitle(_ value: RhythmCategory) -> String {
        switch value {
        case .personalCare: L10n.Category.personalCare
        case .health: L10n.Category.health
        case .vehicle: L10n.Category.vehicle
        case .home: L10n.Category.home
        case .pet: L10n.Category.pet
        case .finance: L10n.Category.finance
        case .work: L10n.Category.work
        case .other: L10n.Category.other
        }
    }
}
