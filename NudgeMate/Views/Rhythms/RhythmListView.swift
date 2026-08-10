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
    @State private var selectedIDs: Set<UUID> = []
    @State private var selectionFrames: [UUID: CGRect] = [:]
    @State private var isSelecting = false
    @State private var isDeleteConfirmationPresented = false

    private var allSelected: Bool {
        !rhythms.isEmpty && selectedIDs.count == rhythms.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NudgeScreenBackground()

                VStack(spacing: 0) {
                    NudgeScreenHeader(
                        title: L10n.Rhythm.title,
                        subtitle: L10n.Home.Nudge.subtitle,
                        itemCount: rhythms.count,
                        isSelecting: isSelecting,
                        allSelected: allSelected,
                        onToggleSelectionMode: toggleSelectionMode,
                        onToggleAll: toggleAll,
                        onAdd: { isCreating = true }
                    )

                    RhythmListContent(
                        rhythms: rhythms,
                        isSelecting: isSelecting,
                        selectedIDs: selectedIDs,
                        onAdd: { isCreating = true },
                        onOpen: openOrSelect,
                        onToggle: toggle,
                        onDelete: delete
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isSelecting {
                    NudgeSelectionActionBar(
                        selectedCount: selectedIDs.count,
                        onDelete: { isDeleteConfirmationPresented = true }
                    )
                }
            }
            .background {
                TwoFingerSelectionInstaller(
                    itemFrames: selectionFrames,
                    selectedIDs: selectedIDs,
                    onSelectionStarted: { isSelecting = true },
                    onSelectionChanged: updateSelection
                )
                .frame(width: 0, height: 0)
            }
            .onPreferenceChange(NudgeSelectionFrameKey.self) { frames in
                selectionFrames = frames
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
        .task { handleNavigation(appState.pendingNavigation) }
        .onChange(of: appState.pendingNavigation) { _, destination in
            handleNavigation(destination)
        }
        .confirmationDialog(
            L10n.Selection.deleteTitle(selectedIDs.count),
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.Selection.deleteAction(selectedIDs.count), role: .destructive) {
                deleteSelected()
            }
            .accessibilityIdentifier("selection.confirmDelete")
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Selection.deleteMessage)
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

    private func toggleSelectionMode() {
        withAnimation(.snappy(duration: 0.24)) {
            isSelecting.toggle()
            if !isSelecting {
                selectedIDs.removeAll()
            }
        }
    }

    private func toggleAll() {
        withAnimation(.snappy(duration: 0.22)) {
            if allSelected {
                selectedIDs.removeAll()
            } else {
                selectedIDs = Set(rhythms.map(\.id))
            }
        }
    }

    private func openOrSelect(_ rhythm: RecurringEvent) {
        if isSelecting {
            updateSelection(rhythm.id, !selectedIDs.contains(rhythm.id))
        } else {
            editingRhythm = rhythm
        }
    }

    private func updateSelection(_ id: UUID, _ shouldSelect: Bool) {
        withAnimation(.snappy(duration: 0.18)) {
            if shouldSelect {
                selectedIDs.insert(id)
            } else {
                selectedIDs.remove(id)
            }
        }
    }

    private func deleteSelected() {
        let targets = rhythms.filter { selectedIDs.contains($0.id) }
        targets.forEach { rhythm in
            appState.nudgeManager.cancelNudge(for: rhythm.id)
            modelContext.delete(rhythm)
        }
        do {
            try modelContext.save()
            selectedIDs.removeAll()
            isSelecting = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggle(_ rhythm: RecurringEvent) {
        let wasMuted = rhythm.isMuted
        rhythm.isMuted.toggle()
        rhythm.updatedAt = .now
        Task {
            do {
                try modelContext.save()
                if rhythm.isMuted {
                    appState.nudgeManager.cancelNudge(for: rhythm.id)
                } else {
                    try await appState.nudgeManager.scheduleNudge(for: rhythm)
                }
            } catch {
                let primaryMessage = error.localizedDescription
                rhythm.isMuted = wasMuted
                rhythm.updatedAt = .now
                do {
                    try modelContext.save()
                    if wasMuted {
                        appState.nudgeManager.cancelNudge(for: rhythm.id)
                    } else {
                        try await appState.nudgeManager.scheduleNudge(for: rhythm)
                    }
                    errorMessage = primaryMessage
                } catch {
                    errorMessage = "\(primaryMessage)\n\(error.localizedDescription)"
                }
            }
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

    private func handleNavigation(_ destination: AppNavigationDestination?) {
        guard let destination, case let .rhythm(id) = destination else { return }
        if let id, let rhythm = rhythms.first(where: { $0.id == id }) {
            editingRhythm = rhythm
        } else if id == nil {
            isCreating = true
        }
        appState.consumeNavigation(.rhythm(id))
    }
}

private struct RhythmListContent: View {
    let rhythms: [RecurringEvent]
    let isSelecting: Bool
    let selectedIDs: Set<UUID>
    let onAdd: () -> Void
    let onOpen: (RecurringEvent) -> Void
    let onToggle: (RecurringEvent) -> Void
    let onDelete: (RecurringEvent) -> Void

    var body: some View {
        if rhythms.isEmpty {
            EmptyStateView(
                icon: .refresh,
                title: L10n.Rhythm.Empty.title,
                message: L10n.Rhythm.Empty.message,
                actionTitle: L10n.Rhythm.add,
                action: onAdd
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(rhythms) { rhythm in
                        RhythmCard(
                            rhythm: rhythm,
                            isSelecting: isSelecting,
                            isSelected: selectedIDs.contains(rhythm.id),
                            onOpen: { onOpen(rhythm) },
                            onToggle: { onToggle(rhythm) },
                            onDelete: { onDelete(rhythm) }
                        )
                        .nudgeSelectionFrame(id: rhythm.id)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, NudgeLayoutMetrics.listBottomClearance)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("rhythm.list")
        }
    }
}

private struct RhythmCard: View {
    let rhythm: RecurringEvent
    let isSelecting: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    NudgeSymbolBadge(symbol: .category(rhythm.category), size: 54)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            Text(categoryTitle)
                                .pretendard(.caption2, weight: .semibold)
                                .foregroundStyle(ColorTheme.primaryNudge)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ColorTheme.brandSoft, in: Capsule())
                            if rhythm.isMuted {
                                Text(L10n.Rhythm.paused)
                                    .pretendard(.caption2, weight: .semibold)
                                    .foregroundStyle(ColorTheme.secondarySnooze)
                            }
                        }
                        Text(rhythm.displayName)
                            .pretendard(.headline, weight: .semibold)
                            .foregroundStyle(ColorTheme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(L10n.Rhythm.Row.detail(
                            rhythm.baseIntervalDays,
                            rhythm.nextExpectedCenterDate.formatted(date: .abbreviated, time: .omitted)
                        ))
                        .pretendard(.subheadline)
                        .foregroundStyle(ColorTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isSelecting {
                Button(action: onOpen) {
                    NudgeSelectionIndicator(isSelected: isSelected)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? L10n.Selection.deselect : L10n.Selection.select)
            } else {
                Menu {
                    Button(rhythm.isMuted ? L10n.Rhythm.resume : L10n.Rhythm.pause, action: onToggle)
                    Button(L10n.Common.delete, role: .destructive, action: onDelete)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                        Text(L10n.Common.moreActions)
                            .pretendard(.caption2, weight: .medium)
                    }
                    .foregroundStyle(ColorTheme.secondaryText)
                    .frame(minWidth: 54, minHeight: 48)
                    .background(ColorTheme.backgroundDeep.opacity(0.75), in: Capsule())
                }
                .accessibilityLabel(L10n.Common.moreActions)
            }
        }
        .nudgeCardSurface(isSelected: isSelected)
        .accessibilityValue(isSelected ? L10n.Selection.selected : "")
    }

    private var categoryTitle: String {
        switch rhythm.category {
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
    @State private var isSaving = false

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
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(L10n.Common.save)
                        }
                    }
                    .disabled(
                        isSaving
                            || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
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
        .accessibilityIdentifier("rhythm.editor.screen")
    }

    private func save() async {
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
        isSaving = true
        defer { isSaving = false }
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

        do {
            if notificationsEnabled {
                try await appState.nudgeManager.scheduleNudge(for: value)
            } else {
                appState.nudgeManager.cancelNudge(for: value.id)
            }
            if rhythm == nil { modelContext.insert(value) }
            try modelContext.save()
            dismiss()
        } catch {
            if rhythm == nil {
                appState.nudgeManager.cancelNudge(for: value.id)
            }
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
