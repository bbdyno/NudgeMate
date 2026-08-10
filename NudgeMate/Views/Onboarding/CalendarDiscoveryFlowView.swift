import SwiftData
import SwiftUI
import UIKit

private typealias L10n = NudgeMateStrings.Localizable

struct CalendarDiscoveryFlowView: View {
    enum Step {
        case selection
        case review
    }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let onFinished: () -> Void

    @State private var step: Step = .selection
    @State private var calendars: [CalendarDescriptor] = []
    @State private var selection = Set<String>()
    @State private var isLoading = true
    @State private var scanProgress = 0.0
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .selection:
                    selectionView
                case .review:
                    CandidateReviewView {
                        do {
                            try appState.finishOnboarding(
                                selectedCalendarIdentifiers: selection,
                                modelContext: modelContext
                            )
                            onFinished()
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .background(ColorTheme.background.ignoresSafeArea())
            .navigationTitle(step == .selection ? L10n.Calendar.Selection.title : L10n.Candidate.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
        }
        .task { await requestAndLoadCalendars() }
        .alert(L10n.Common.error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.Common.confirm, role: .cancel) {}
            Button(L10n.Home.Permission.openSettings) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var selectionView: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView(L10n.Calendar.Selection.loading)
                    .tint(ColorTheme.primaryNudge)
                Spacer()
            } else {
                List {
                    Section {
                        Text(L10n.Calendar.Selection.message)
                            .pretendard(.subheadline)
                            .foregroundStyle(ColorTheme.secondaryText)
                    }

                    ForEach(groupedSources, id: \.0) { source, values in
                        Section(source) {
                            ForEach(values) { calendar in
                                Toggle(isOn: binding(for: calendar.identifier)) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(calendar.title)
                                            .pretendard(.body)
                                        if let reason = calendar.defaultExclusionReason {
                                            Text(reason.localizedExplanation)
                                                .pretendard(.caption)
                                                .foregroundStyle(ColorTheme.secondaryText)
                                        }
                                    }
                                }
                                .tint(ColorTheme.primaryNudge)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)

                VStack(spacing: 10) {
                    if scanProgress > 0 {
                        ProgressView(value: scanProgress)
                            .tint(ColorTheme.primaryNudge)
                            .accessibilityLabel(L10n.Calendar.Scan.progress)
                    }
                    Button {
                        Task { await scan() }
                    } label: {
                        Text(L10n.Calendar.Selection.scan(selection.count))
                            .pretendard(.headline, weight: .semibold)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(ColorTheme.primaryNudge, in: Capsule())
                    .disabled(selection.isEmpty || scanProgress > 0)
                    .opacity(selection.isEmpty ? 0.45 : 1)
                }
                .padding(20)
                .background(.bar)
            }
        }
    }

    private var groupedSources: [(String, [CalendarDescriptor])] {
        Dictionary(grouping: calendars, by: \.sourceTitle)
            .map { ($0.key, $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.0 < $1.0 }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selection.contains(id) },
            set: { isSelected in
                if isSelected { selection.insert(id) } else { selection.remove(id) }
            }
        )
    }

    private func requestAndLoadCalendars() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await appState.eventKitManager.requestAccess()
            calendars = try await appState.eventKitManager.loadCalendars()
            selection = Set(
                calendars
                    .filter { $0.defaultExclusionReason == nil }
                    .map(\.identifier)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scan() async {
        scanProgress = 0.15
        do {
            let events = try await appState.eventKitManager.fetchEvents(
                pastMonths: 12,
                futureDays: 0,
                calendarIdentifiers: selection
            )
            scanProgress = 0.55
            let suppressions = try modelContext.fetch(FetchDescriptor<SuppressedPatternRecord>())
            let activeSignatures = Set(
                suppressions
                    .filter { $0.suppressUntil > .now }
                    .map(\.normalizedSignature)
            )
            let result = CalendarScanService().scan(
                events: events,
                suppressedSignatures: activeSignatures
            )
            for candidate in result.candidates {
                modelContext.insert(try PatternCandidateRecord(value: candidate))
            }
            try modelContext.save()
            scanProgress = 1
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                step = .review
            }
        } catch {
            scanProgress = 0
            errorMessage = error.localizedDescription
        }
    }
}

private extension CalendarExclusionReason {
    var localizedExplanation: String {
        switch self {
        case .birthdays: L10n.Calendar.Exclusion.birthdays
        case .holidays: L10n.Calendar.Exclusion.holidays
        case .subscribed: L10n.Calendar.Exclusion.subscribed
        case .readOnly: L10n.Calendar.Exclusion.readOnly
        }
    }
}

private struct CandidateReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PatternCandidateRecord.confidenceScore, order: .reverse)
    private var candidates: [PatternCandidateRecord]

    @Query private var rhythms: [RecurringEvent]

    @State private var errorMessage: String?

    let onFinished: () -> Void

    private var pending: [PatternCandidateRecord] {
        candidates.filter { $0.decision == .pending || $0.decision == .modified }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if pending.isEmpty {
                    EmptyStateView(
                        icon: .empty,
                        title: L10n.Candidate.emptyTitle,
                        message: L10n.Candidate.emptyMessage
                    )
                    .padding(.top, 40)
                } else {
                    Text(L10n.Candidate.message)
                        .pretendard(.subheadline)
                        .foregroundStyle(ColorTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(pending) { candidate in
                        CandidateCard(candidate: candidate) { name, category in
                            Task {
                                await accept(candidate, name: name, category: category)
                            }
                        } onReject: {
                            reject(candidate)
                        }
                    }
                }

                Button(action: onFinished) {
                    Text(L10n.Candidate.finish)
                        .pretendard(.headline, weight: .semibold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(ColorTheme.primaryNudge, in: Capsule())
                .padding(.top, 10)
            }
            .padding(20)
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

    private func accept(
        _ record: PatternCandidateRecord,
        name: String,
        category: RhythmCategory
    ) async {
        let activeAdaptiveCount = rhythms.filter {
            $0.mode == .adaptive && $0.lifecycleState == .active
        }.count
        if EntitlementPolicy().adaptiveRhythmCreation(
            activeAdaptiveCount: activeAdaptiveCount,
            isPro: appState.subscriptionManager.isPro
        ) == .requiresPro {
            appState.presentPaywall()
            return
        }
        do {
            var candidate = try record.domainValue()
            candidate.suggestedDisplayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            candidate.categorySuggestion = category
            candidate.decision = .accepted
            let event = RecurringEvent(
                id: candidate.id,
                title: candidate.suggestedDisplayName,
                baseInterval: max(1, Int(candidate.medianIntervalDays.rounded())),
                historyDates: candidate.eventReferences.filter(\.isIncluded).map(\.occurredAt),
                nextPredictedDate: candidate.expectedWindow.center
            )
            event.category = category
            event.normalizedName = candidate.normalizedKey
            event.variationDays = candidate.variationDays
            event.confidenceScore = candidate.confidenceScore
            event.confidenceBand = candidate.confidenceBand
            event.nextExpectedStartDate = candidate.expectedWindow.start
            event.nextExpectedEndDate = candidate.expectedWindow.end
            event.sourceCalendarIdentifiers = Array(
                Set(candidate.eventReferences.map(\.calendarIdentifier))
            ).sorted()
            record.suggestedDisplayName = event.displayName
            record.categorySuggestion = category
            record.decision = .accepted
            modelContext.insert(event)
            do {
                try modelContext.save()
            } catch {
                modelContext.delete(event)
                record.decision = .pending
                throw error
            }

            do {
                try await appState.nudgeManager.scheduleNudge(for: event)
            } catch {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reject(_ record: PatternCandidateRecord) {
        do {
            let calendarIDs = try record.domainValue().eventReferences.map(\.calendarIdentifier)
            let suppression = SuppressedPatternRecord(
                value: SuppressedPattern(
                    id: UUID(),
                    normalizedSignature: record.normalizedKey,
                    rejectedAt: .now,
                    suppressUntil: Calendar.autoupdatingCurrent.date(
                        byAdding: .month,
                        value: 6,
                        to: .now
                    ) ?? .now.addingTimeInterval(15_552_000),
                    sourceCalendarIdentifiers: Array(Set(calendarIDs)).sorted(),
                    reason: .notInterested
                )
            )
            record.decision = .rejected
            modelContext.insert(suppression)
            do {
                try modelContext.save()
            } catch {
                record.decision = .pending
                modelContext.delete(suppression)
                throw error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CandidateCard: View {
    let candidate: PatternCandidateRecord
    let onAccept: (String, RhythmCategory) -> Void
    let onReject: () -> Void

    @State private var name: String
    @State private var category: RhythmCategory

    init(
        candidate: PatternCandidateRecord,
        onAccept: @escaping (String, RhythmCategory) -> Void,
        onReject: @escaping () -> Void
    ) {
        self.candidate = candidate
        self.onAccept = onAccept
        self.onReject = onReject
        _name = State(initialValue: candidate.suggestedDisplayName)
        _category = State(initialValue: candidate.categorySuggestion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(L10n.Candidate.name, text: $name)
                .pretendard(.headline, weight: .semibold)
                .textFieldStyle(.roundedBorder)

            HStack {
                Label {
                    Text(L10n.Candidate.interval(Int(candidate.medianIntervalDays.rounded())))
                } icon: {
                    NudgeSymbolImage(symbol: .calendar, pointSize: 20)
                }
                Spacer()
                Text(L10n.Candidate.samples(candidate.sampleCount))
            }
            .pretendard(.subheadline)
            .foregroundStyle(ColorTheme.secondaryText)

            Picker(L10n.Candidate.category, selection: $category) {
                ForEach(RhythmCategory.allCases, id: \.self) { value in
                    Text(value.localizedTitle).tag(value)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 10) {
                Button(L10n.Common.reject, action: onReject)
                    .buttonStyle(.bordered)
                    .tint(ColorTheme.secondaryText)
                Button(L10n.Common.accept) {
                    onAccept(name, category)
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTheme.primaryNudge)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension RhythmCategory {
    var localizedTitle: String {
        switch self {
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
