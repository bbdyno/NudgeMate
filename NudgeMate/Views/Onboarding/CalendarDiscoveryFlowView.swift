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
            ZStack {
                NudgeScreenBackground()

                switch step {
                case .selection:
                    CalendarSelectionScreen(
                        calendars: calendars,
                        selection: $selection,
                        isLoading: isLoading,
                        scanProgress: scanProgress,
                        onScan: { Task { await scan() } }
                    )
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                        .pretendard(.subheadline, weight: .semibold)
                        .foregroundStyle(ColorTheme.primaryNudge)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
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

private struct CalendarSelectionScreen: View {
    let calendars: [CalendarDescriptor]
    @Binding var selection: Set<String>
    let isLoading: Bool
    let scanProgress: Double
    let onScan: () -> Void

    private var groupedSources: [(String, [CalendarDescriptor])] {
        Dictionary(grouping: calendars, by: \.sourceTitle)
            .map { ($0.key, $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            CalendarSelectionHeader(selectedCount: selection.count)

            if isLoading {
                Spacer()
                ProgressView(L10n.Calendar.Selection.loading)
                    .pretendard(.body)
                    .tint(ColorTheme.primaryNudge)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(groupedSources, id: \.0) { source, values in
                            CalendarSourceGroup(
                                source: source,
                                calendars: values,
                                selection: $selection
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)

                CalendarScanAction(
                    selectedCount: selection.count,
                    progress: scanProgress,
                    action: onScan
                )
            }
        }
        .accessibilityIdentifier("calendar.selection.screen")
    }
}

private struct CalendarSelectionHeader: View {
    let selectedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(L10n.Calendar.Selection.title)
                    .pretendard(.largeTitle, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryText)

                Spacer(minLength: 8)

                Text(L10n.Onboarding.Selection.count(selectedCount))
                    .pretendard(.caption, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryNudge)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(ColorTheme.brandSoft, in: Capsule())
            }

            Text(L10n.Onboarding.Permission.title)
                .pretendard(.title3, weight: .bold)
                .foregroundStyle(ColorTheme.primaryText)

            Text(L10n.Calendar.Selection.message)
                .pretendard(.subheadline)
                .foregroundStyle(ColorTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Circle()
                    .fill(ColorTheme.success)
                    .frame(width: 8, height: 8)
                Text(L10n.Onboarding.Selection.privacy)
                    .pretendard(.caption, weight: .semibold)
                    .foregroundStyle(ColorTheme.success)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
}

private struct CalendarSourceGroup: View {
    let source: String
    let calendars: [CalendarDescriptor]
    @Binding var selection: Set<String>

    private var localizedSource: String {
        switch source {
        case "Default":
            L10n.Calendar.Source.default
        case "Other":
            L10n.Calendar.Source.other
        case "Subscribed Calendars":
            L10n.Calendar.Source.subscribed
        default:
            source
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedSource)
                .pretendard(.caption, weight: .bold)
                .foregroundStyle(ColorTheme.secondaryText)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(calendars.enumerated()), id: \.element.id) { index, calendar in
                    CalendarSelectionRow(
                        calendar: calendar,
                        isSelected: selection.contains(calendar.identifier)
                    ) {
                        toggle(calendar.identifier)
                    }

                    if index < calendars.count - 1 {
                        Rectangle()
                            .fill(ColorTheme.separator)
                            .frame(height: 1)
                            .padding(.leading, 55)
                    }
                }
            }
            .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ColorTheme.separator, lineWidth: 1)
            }
        }
    }

    private func toggle(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
}

private struct CalendarSelectionRow: View {
    let calendar: CalendarDescriptor
    let isSelected: Bool
    let action: () -> Void

    private var dotColor: Color {
        ColorTheme.primaryNudge
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 12, height: 12)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(calendar.title)
                        .pretendard(.body, weight: .semibold)
                        .foregroundStyle(ColorTheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let reason = calendar.defaultExclusionReason {
                        Text(reason.localizedExplanation)
                            .pretendard(.caption)
                            .foregroundStyle(ColorTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                CalendarSelectionCheck(isSelected: isSelected)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CalendarSelectionCheck: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? ColorTheme.primaryNudge : Color.clear)
            Circle()
                .stroke(isSelected ? ColorTheme.primaryNudge : ColorTheme.separator, lineWidth: 1.5)

            if isSelected {
                CalendarCheckMark()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .padding(6)
            }
        }
        .frame(width: 26, height: 26)
    }
}

private struct CalendarCheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX * 0.94, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct CalendarScanAction: View {
    let selectedCount: Int
    let progress: Double
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if progress > 0 {
                ProgressView(value: progress)
                    .tint(ColorTheme.primaryNudge)
                    .accessibilityLabel(L10n.Calendar.Scan.progress)
            }

            Button(action: action) {
                Text(
                    selectedCount == 1
                        ? L10n.Calendar.Selection.scanOne
                        : L10n.Calendar.Selection.scan(selectedCount)
                )
                    .pretendard(.headline, weight: .bold)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(NudgePrimaryButtonStyle())
            .disabled(selectedCount == 0 || progress > 0)
            .opacity(selectedCount == 0 ? 0.45 : 1)
            .accessibilityIdentifier("calendar.selection.scan")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
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
                .buttonStyle(NudgePrimaryButtonStyle())
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

            ViewThatFits(in: .horizontal) {
                HStack {
                    intervalLabel
                    Spacer(minLength: 10)
                    sampleLabel
                }

                VStack(alignment: .leading, spacing: 7) {
                    intervalLabel
                    sampleLabel
                }
            }
            .pretendard(.subheadline)
            .foregroundStyle(ColorTheme.secondaryText)

            Picker(L10n.Candidate.category, selection: $category) {
                ForEach(RhythmCategory.allCases, id: \.self) { value in
                    Text(value.localizedTitle).tag(value)
                }
            }
            .pickerStyle(.menu)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    rejectButton
                    acceptButton
                }

                VStack(spacing: 8) {
                    acceptButton
                        .frame(maxWidth: .infinity)
                    rejectButton
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .nudgeCardSurface()
    }

    private var intervalLabel: some View {
        Label {
            Text(L10n.Candidate.interval(Int(candidate.medianIntervalDays.rounded())))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            NudgeSymbolImage(symbol: .calendar, pointSize: 20)
        }
    }

    private var sampleLabel: some View {
        Text(L10n.Candidate.samples(candidate.sampleCount))
            .fixedSize(horizontal: true, vertical: false)
    }

    private var rejectButton: some View {
        Button(L10n.Common.reject, action: onReject)
            .buttonStyle(.bordered)
            .tint(ColorTheme.secondaryText)
    }

    private var acceptButton: some View {
        Button(L10n.Common.accept) {
            onAccept(name, category)
        }
        .buttonStyle(.borderedProminent)
        .tint(ColorTheme.primaryNudge)
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
