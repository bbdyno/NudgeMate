import SwiftUI
import WidgetKit

struct PrepWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: PrepWidgetSnapshot
}

struct PrepWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrepWidgetEntry {
        PrepWidgetEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrepWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : PrepWidgetSnapshotStore.load()
        completion(PrepWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrepWidgetEntry>) -> Void) {
        let now = Date.now
        let entry = PrepWidgetEntry(date: now, snapshot: PrepWidgetSnapshotStore.load())
        let calendar = Calendar.autoupdatingCurrent
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct PrepWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: NudgeMateSharedConfiguration.widgetKind,
            provider: PrepWidgetProvider()
        ) { entry in
            PrepWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [WidgetDesign.cream, WidgetDesign.lavenderSoft.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName(WidgetL10n.title)
        .description(WidgetL10n.emptyMessage)
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

private struct PrepWidgetView: View {
    let entry: PrepWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .accessoryInline:
                accessoryInlineView
            case .accessoryCircular:
                accessoryCircularView
            case .accessoryRectangular:
                accessoryRectangularView
            default:
                smallView
            }
        }
        .widgetURL(primaryItem?.deepLinkURL ?? URL(string: "nudgemate://prep"))
    }

    private var primaryItem: PrepWidgetItem? {
        entry.snapshot.items.first
    }

    @ViewBuilder
    private var smallView: some View {
        if let item = primaryItem {
            VStack(alignment: .leading, spacing: 9) {
                brandHeader
                Spacer(minLength: 0)
                Text(dayLabel(for: item))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(dayColor(for: item))
                Text(title(for: item))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(WidgetDesign.ink)
                    .lineLimit(2)
                statusPill(for: item)
            }
        } else {
            emptyView(compact: true)
        }
    }

    @ViewBuilder
    private var mediumView: some View {
        if let item = primaryItem {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    brandHeader
                    Spacer(minLength: 0)
                    Text(dayLabel(for: item))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(dayColor(for: item))
                    Text(title(for: item))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(WidgetDesign.ink)
                        .lineLimit(2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    statusPill(for: item)
                    if item.showsDetails && !item.nextAction.isEmpty {
                        Label(WidgetL10n.nextAction, systemImage: "arrow.turn.down.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(WidgetDesign.secondaryInk)
                        Text(item.nextAction)
                            .font(.caption)
                            .foregroundStyle(WidgetDesign.ink)
                            .lineLimit(2)
                    } else {
                        Text(item.targetDate, style: .relative)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(WidgetDesign.secondaryInk)
                    }
                    Spacer(minLength: 0)
                    let additionalCount = max(0, entry.snapshot.items.count - 1)
                    if additionalCount > 0 {
                        Text(WidgetL10n.more(additionalCount))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(WidgetDesign.lavender)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            emptyView(compact: false)
        }
    }

    private var accessoryInlineView: some View {
        Group {
            if let item = primaryItem {
                Label("\(dayLabel(for: item)) · \(title(for: item))", systemImage: "sparkles")
            } else {
                Label(WidgetL10n.emptyTitle, systemImage: "sparkles")
            }
        }
    }

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let item = primaryItem {
                VStack(spacing: 0) {
                    Image(systemName: "checklist")
                        .font(.caption.weight(.semibold))
                    Text(shortDayLabel(for: item))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.65)
                }
            } else {
                Image(systemName: "sparkles")
            }
        }
    }

    private var accessoryRectangularView: some View {
        Group {
            if let item = primaryItem {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(shortDayLabel(for: item)) · \(WidgetL10n.status(item.status))")
                        .font(.caption2.weight(.semibold))
                    Text(title(for: item))
                        .font(.headline)
                        .lineLimit(1)
                    Text(item.showsDetails && !item.nextAction.isEmpty ? item.nextAction : WidgetL10n.openApp)
                        .font(.caption2)
                        .lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(WidgetL10n.title).font(.caption2.weight(.semibold))
                    Text(WidgetL10n.emptyTitle).font(.headline)
                    Text(WidgetL10n.openApp).font(.caption2)
                }
            }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(WidgetDesign.coral)
            Text(WidgetL10n.upNext)
                .font(.caption2.weight(.bold))
                .foregroundStyle(WidgetDesign.secondaryInk)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }

    private func statusPill(for item: PrepWidgetItem) -> some View {
        Text(WidgetL10n.status(item.status))
            .font(.caption2.weight(.bold))
            .foregroundStyle(WidgetDesign.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(WidgetDesign.lavenderSoft, in: Capsule())
    }

    private func emptyView(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Image(systemName: "sparkles")
                .font(compact ? .title2 : .title)
                .foregroundStyle(WidgetDesign.coral)
            Spacer(minLength: 0)
            Text(WidgetL10n.emptyTitle)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(WidgetDesign.ink)
            Text(WidgetL10n.emptyMessage)
                .font(.caption)
                .foregroundStyle(WidgetDesign.secondaryInk)
                .lineLimit(compact ? 3 : 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func dayLabel(for item: PrepWidgetItem) -> String {
        let days = item.daysRemaining(at: entry.date)
        if days == 0 { return WidgetL10n.target }
        return days > 0 ? "D-\(days)" : "D+\(abs(days))"
    }

    private func title(for item: PrepWidgetItem) -> String {
        item.showsDetails && !item.title.isEmpty ? item.title : WidgetL10n.privatePrep
    }

    private func shortDayLabel(for item: PrepWidgetItem) -> String {
        let days = item.daysRemaining(at: entry.date)
        if days == 0 { return "D-Day" }
        return days > 0 ? "D-\(days)" : "+\(abs(days))"
    }

    private func dayColor(for item: PrepWidgetItem) -> Color {
        item.daysRemaining(at: entry.date) <= 3 ? WidgetDesign.coral : WidgetDesign.lavender
    }
}

private extension PrepWidgetSnapshot {
    static var preview: PrepWidgetSnapshot {
        let target = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        return PrepWidgetSnapshot(
            generatedAt: .now,
            items: [
                PrepWidgetItem(
                    id: UUID(),
                    title: "Project presentation",
                    targetDate: target,
                    status: .inProgress,
                    nextAction: "Review the final slides",
                    showsDetails: true
                )
            ]
        )
    }
}
