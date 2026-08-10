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
    @State private var selectedIDs: Set<UUID> = []
    @State private var selectionFrames: [UUID: CGRect] = [:]
    @State private var isSelecting = false
    @State private var isDeleteConfirmationPresented = false

    private var allSelected: Bool {
        !preps.isEmpty && selectedIDs.count == preps.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NudgeScreenBackground()

                VStack(spacing: 0) {
                    NudgeScreenHeader(
                        title: L10n.Prep.title,
                        subtitle: L10n.Home.Prep.subtitle,
                        itemCount: preps.count,
                        isSelecting: isSelecting,
                        allSelected: allSelected,
                        onToggleSelectionMode: toggleSelectionMode,
                        onToggleAll: toggleAll,
                        onAdd: { isCreating = true }
                    )

                    PrepListContent(
                        preps: preps,
                        isSelecting: isSelecting,
                        selectedIDs: selectedIDs,
                        onAdd: { isCreating = true },
                        onOpen: openOrSelect,
                        onStatusChange: updateStatus,
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
            PrepEditorView(prep: nil)
                .environment(appState)
        }
        .sheet(item: $editingPrep) { prep in
            PrepEditorView(prep: prep)
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
                selectedIDs = Set(preps.map(\.id))
            }
        }
    }

    private func openOrSelect(_ prep: EventPrep) {
        if isSelecting {
            updateSelection(prep.id, !selectedIDs.contains(prep.id))
        } else {
            editingPrep = prep
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

    private func updateStatus(_ prep: EventPrep, _ status: PrepStatus) {
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

    private func deleteSelected() {
        let targets = preps.filter { selectedIDs.contains($0.id) }
        targets.forEach { prep in
            appState.nudgeManager.cancelPrepReminder(for: prep.id)
            modelContext.delete(prep)
        }
        do {
            try modelContext.save()
            selectedIDs.removeAll()
            isSelecting = false
            Task { try? await appState.nudgeManager.synchronizeWidgetsAndActivities(modelContext: modelContext) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ prep: EventPrep) {
        appState.nudgeManager.cancelPrepReminder(for: prep.id)
        modelContext.delete(prep)
        do {
            try modelContext.save()
            Task { try? await appState.nudgeManager.synchronizeWidgetsAndActivities(modelContext: modelContext) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleNavigation(_ destination: AppNavigationDestination?) {
        guard let destination, case let .prep(id) = destination else { return }
        if let id, let prep = preps.first(where: { $0.id == id }) {
            editingPrep = prep
        } else if id == nil {
            isCreating = true
        }
        appState.consumeNavigation(.prep(id))
    }
}

private struct PrepListContent: View {
    let preps: [EventPrep]
    let isSelecting: Bool
    let selectedIDs: Set<UUID>
    let onAdd: () -> Void
    let onOpen: (EventPrep) -> Void
    let onStatusChange: (EventPrep, PrepStatus) -> Void
    let onDelete: (EventPrep) -> Void

    var body: some View {
        if preps.isEmpty {
            EmptyStateView(
                icon: .calendar,
                title: L10n.Prep.Empty.title,
                message: L10n.Prep.Empty.message,
                actionTitle: L10n.Prep.add,
                action: onAdd
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(preps) { prep in
                        PrepCard(
                            prep: prep,
                            isSelecting: isSelecting,
                            isSelected: selectedIDs.contains(prep.id),
                            onOpen: { onOpen(prep) },
                            onStatusChange: { onStatusChange(prep, $0) },
                            onDelete: { onDelete(prep) }
                        )
                        .nudgeSelectionFrame(id: prep.id)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, NudgeLayoutMetrics.listBottomClearance)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("prep.list")
        }
    }
}

private struct PrepCard: View {
    let prep: EventPrep
    let isSelecting: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onStatusChange: (PrepStatus) -> Void
    let onDelete: () -> Void

    private var daysRemaining: Int {
        Calendar.autoupdatingCurrent.dateComponents(
            [.day],
            from: Calendar.autoupdatingCurrent.startOfDay(for: .now),
            to: Calendar.autoupdatingCurrent.startOfDay(for: prep.targetDate)
        ).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button(action: onOpen) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(ColorTheme.brandSoft)
                            NudgeSymbolImage(symbol: .calendar, pointSize: 24)
                        }
                        .frame(width: 54, height: 54)
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(dayLabel)
                                .pretendard(.caption2, weight: .bold)
                                .foregroundStyle(dayLabelColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(dayLabelColor.opacity(0.13), in: Capsule())
                            Text(prep.title)
                                .pretendard(.headline, weight: .semibold)
                                .foregroundStyle(ColorTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(prep.targetDate, format: .dateTime.month(.abbreviated).day().weekday(.abbreviated))
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

            if !prep.nextActionNote.isEmpty {
                Text(prep.nextActionNote)
                    .pretendard(.caption)
                    .foregroundStyle(ColorTheme.secondarySnooze)
                    .lineLimit(2)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTheme.backgroundDeep.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            }

            if !isSelecting && prep.status != .ready && prep.targetDate >= .now {
                PrepReadinessControl(
                    selection: prep.status,
                    onSelectionChanged: onStatusChange
                )

                Label(
                    String(localized: "prep.liveActivity.hint"),
                    systemImage: "dot.radiowaves.left.and.right"
                )
                .pretendard(.caption2)
                .foregroundStyle(ColorTheme.secondaryText)
            }
        }
        .nudgeCardSurface(isSelected: isSelected)
        .accessibilityValue(isSelected ? L10n.Selection.selected : "")
    }

    private var dayLabel: String {
        daysRemaining >= 0 ? "D-\(daysRemaining)" : L10n.Selection.past
    }

    private var dayLabelColor: Color {
        daysRemaining <= 3 ? ColorTheme.warning : ColorTheme.primaryNudge
    }
}

private struct PrepReadinessControl: View {
    let selection: PrepStatus
    let onSelectionChanged: (PrepStatus) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PrepStatus.allCases) { status in
                Button {
                    onSelectionChanged(status)
                } label: {
                    Text(status.localizedTitle)
                        .pretendard(.caption2, weight: selection == status ? .bold : .medium)
                        .foregroundStyle(
                            selection == status ? ColorTheme.cardBackground : ColorTheme.secondaryText
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            selection == status ? ColorTheme.primaryNudge : ColorTheme.backgroundDeep,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == status ? .isSelected : [])
            }
        }
    }
}

struct PrepEditorView: View {
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
    @State private var isSaving = false

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
                            || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        .accessibilityIdentifier("prep.editor.screen")
    }

    private func save() async {
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
        isSaving = true
        defer { isSaving = false }
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

        do {
            if notificationsEnabled && value.status != .ready {
                try await appState.nudgeManager.schedulePrepReminder(for: value)
            } else {
                appState.nudgeManager.cancelPrepReminder(for: value.id)
            }
            if prep == nil { modelContext.insert(value) }
            try modelContext.save()
            try await appState.nudgeManager.synchronizeWidgetsAndActivities(modelContext: modelContext)
            dismiss()
        } catch {
            if prep == nil {
                appState.nudgeManager.cancelPrepReminder(for: value.id)
            }
            errorMessage = error.localizedDescription
        }
    }
}
