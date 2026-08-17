import SwiftData
import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct CalendarEventComposerDraft: Identifiable, Equatable {
    let id: UUID
    var title: String
    var startDate: Date
    var durationMinutes: Int
    var calendarIdentifier: String?
    var rhythmID: UUID?

    init(
        id: UUID = UUID(),
        title: String = "",
        startDate: Date,
        durationMinutes: Int = 60,
        calendarIdentifier: String? = nil,
        rhythmID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.calendarIdentifier = calendarIdentifier
        self.rhythmID = rhythmID
    }
}

private struct CalendarConflictQuery: Hashable {
    let title: String
    let startDate: Date
    let durationMinutes: Int
    let calendarIdentifier: String?
}

struct CalendarEventComposerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let draft: CalendarEventComposerDraft
    let rhythm: RecurringEvent?
    let onSaved: (String) -> Void

    @State private var title: String
    @State private var startDate: Date
    @State private var durationMinutes: Int
    @State private var calendarIdentifier: String?
    @State private var writableCalendars: [CalendarDescriptor] = []
    @State private var conflicts: [CalendarEventSnapshot] = []
    @State private var isCheckingConflicts = false
    @State private var isSaving = false
    @State private var hasCreatedEvent = false
    @State private var allowPossibleDuplicate = false
    @State private var errorMessage: String?
    @State private var postSaveWarning: String?

    init(
        draft: CalendarEventComposerDraft,
        rhythm: RecurringEvent? = nil,
        onSaved: @escaping (String) -> Void
    ) {
        self.draft = draft
        self.rhythm = rhythm
        self.onSaved = onSaved
        _title = State(initialValue: draft.title)
        _startDate = State(initialValue: draft.startDate)
        _durationMinutes = State(initialValue: draft.durationMinutes)
        _calendarIdentifier = State(initialValue: draft.calendarIdentifier)
    }

    var body: some View {
        NavigationStack {
            Form {
                CalendarComposerDetailsSection(
                    title: $title,
                    startDate: $startDate,
                    durationMinutes: $durationMinutes
                )
                CalendarComposerCalendarSection(
                    calendars: writableCalendars,
                    selection: $calendarIdentifier
                )
                CalendarComposerConflictSection(
                    conflicts: conflicts,
                    isChecking: isCheckingConflicts,
                    hasPossibleDuplicate: hasPossibleDuplicate,
                    allowPossibleDuplicate: $allowPossibleDuplicate
                )
            }
            .pretendard(.body)
            .nudgeFormStyle()
            .navigationTitle(
                rhythm == nil
                    ? L10n.Calendar.Composer.newTitle
                    : L10n.Calendar.Composer.rhythmTitle
            )
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
                            Text(L10n.Calendar.Composer.add)
                        }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("calendar.composer.save")
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .task { await loadCalendars() }
        .task(id: conflictQuery) { await checkConflicts() }
        .alert(L10n.Common.error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.Common.confirm, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(L10n.App.name, isPresented: Binding(
            get: { postSaveWarning != nil },
            set: { if !$0 { postSaveWarning = nil } }
        )) {
            Button(L10n.Common.confirm) { dismiss() }
        } message: {
            Text(postSaveWarning ?? "")
        }
        .accessibilityIdentifier("calendar.composer.screen")
    }

    private var conflictQuery: CalendarConflictQuery {
        CalendarConflictQuery(
            title: title,
            startDate: startDate,
            durationMinutes: durationMinutes,
            calendarIdentifier: calendarIdentifier
        )
    }

    private var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(max(1, durationMinutes) * 60))
    }

    private var hasPossibleDuplicate: Bool {
        let normalizedTitle = EventNormalizer().normalize(title)
        return conflicts.contains {
            EventNormalizer().normalize($0.title) == normalizedTitle
                && abs($0.startDate.timeIntervalSince(startDate)) < 300
        }
    }

    private var canSave: Bool {
        !isSaving
            && !hasCreatedEvent
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!hasPossibleDuplicate || allowPossibleDuplicate)
    }

    private func loadCalendars() async {
        do {
            let calendars: [CalendarDescriptor]
            do {
                calendars = try await appState.eventKitManager.loadCalendars()
            } catch CalendarError.unavailable {
                _ = try await appState.eventKitManager.requestAccess()
                calendars = try await appState.eventKitManager.loadCalendars()
            }
            writableCalendars = calendars.filter(\.allowsContentModifications)
            if calendarIdentifier == nil {
                calendarIdentifier = preferredCalendarIdentifier(in: writableCalendars)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preferredCalendarIdentifier(
        in calendars: [CalendarDescriptor]
    ) -> String? {
        if let preferred = rhythm?.preferredCalendarIdentifier,
           calendars.contains(where: { $0.identifier == preferred }) {
            return preferred
        }
        return calendars.first?.identifier
    }

    private func checkConflicts() async {
        guard appState.eventKitManager.authorizationState == .fullAccess else { return }
        isCheckingConflicts = true
        allowPossibleDuplicate = false
        defer { isCheckingConflicts = false }

        do {
            try await Task.sleep(for: .milliseconds(250))
            try Task.checkCancellation()
            conflicts = try await appState.eventKitManager.conflictingEvents(
                startDate: startDate,
                endDate: endDate,
                calendarIdentifier: calendarIdentifier
            )
        } catch is CancellationError {
            return
        } catch {
            conflicts = []
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await appState.eventKitManager.createCalendarEvent(
                title: trimmedTitle,
                startDate: startDate,
                duration: TimeInterval(durationMinutes * 60),
                calendarIdentifier: calendarIdentifier,
                idempotencyKey: draft.id
            )
            hasCreatedEvent = true
            onSaved(trimmedTitle)
            do {
                try await updateRhythmAfterCreationIfNeeded()
            } catch {
                postSaveWarning = L10n.Calendar.Composer.postSaveWarning(
                    error.localizedDescription
                )
                return
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateRhythmAfterCreationIfNeeded() async throws {
        guard let rhythm else { return }
        rhythm.preferredCalendarIdentifier = calendarIdentifier
        rhythm.defaultEventDurationMinutes = durationMinutes
        let components = Calendar.autoupdatingCurrent.dateComponents(
            [.hour, .minute],
            from: startDate
        )
        rhythm.defaultEventStartHour = components.hour
        rhythm.defaultEventStartMinute = components.minute
        rhythm.nextPredictedDate = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: rhythm.baseIntervalDays,
            to: startDate
        ) ?? startDate.addingTimeInterval(TimeInterval(rhythm.baseIntervalDays * 86_400))
        rhythm.updatedAt = .now
        try modelContext.save()
        try await appState.nudgeManager.scheduleNudge(for: rhythm)
    }
}

private struct CalendarComposerDetailsSection: View {
    @Binding var title: String
    @Binding var startDate: Date
    @Binding var durationMinutes: Int

    var body: some View {
        Section(L10n.Calendar.Composer.details) {
            TextField(L10n.Calendar.Composer.title, text: $title)
                .textInputAutocapitalization(.sentences)
                .accessibilityIdentifier("calendar.composer.title")
            DatePicker(
                L10n.Calendar.Composer.startDate,
                selection: $startDate,
                in: Date.now...,
                displayedComponents: [.date, .hourAndMinute]
            )
            Picker(L10n.Calendar.Composer.duration, selection: $durationMinutes) {
                ForEach([30, 60, 90, 120], id: \.self) { minutes in
                    Text(L10n.Calendar.Composer.minutes(minutes)).tag(minutes)
                }
            }
        }
    }
}

private struct CalendarComposerCalendarSection: View {
    let calendars: [CalendarDescriptor]
    @Binding var selection: String?

    var body: some View {
        Section(L10n.Calendar.Composer.calendar) {
            if calendars.isEmpty {
                ProgressView(L10n.Calendar.Selection.loading)
            } else {
                Picker(L10n.Calendar.Composer.calendar, selection: $selection) {
                    ForEach(calendars) { calendar in
                        Text(calendar.title).tag(Optional(calendar.identifier))
                    }
                }
            }
        }
    }
}

private struct CalendarComposerConflictSection: View {
    let conflicts: [CalendarEventSnapshot]
    let isChecking: Bool
    let hasPossibleDuplicate: Bool
    @Binding var allowPossibleDuplicate: Bool

    var body: some View {
        Section(L10n.Calendar.Composer.conflicts) {
            if isChecking {
                ProgressView(L10n.Calendar.Composer.checking)
            } else if conflicts.isEmpty {
                Label(L10n.Calendar.Composer.noConflicts, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(ColorTheme.success)
            } else {
                Label(
                    L10n.Calendar.Composer.conflictCount(conflicts.count),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(ColorTheme.warning)

                ForEach(conflicts.prefix(3)) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title).pretendard(.subheadline, weight: .semibold)
                        Text(event.startDate, format: .dateTime.weekday().hour().minute())
                            .pretendard(.caption)
                            .foregroundStyle(ColorTheme.secondaryText)
                    }
                }

                if hasPossibleDuplicate {
                    Text(L10n.Calendar.Composer.duplicateWarning)
                        .foregroundStyle(ColorTheme.destructive)
                    Toggle(
                        L10n.Calendar.Composer.allowDuplicate,
                        isOn: $allowPossibleDuplicate
                    )
                    .tint(ColorTheme.primaryNudge)
                }
            }
        }
    }
}
