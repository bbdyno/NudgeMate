import ActivityKit
import SwiftUI
import WidgetKit

struct PrepLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrepActivityAttributes.self) { context in
            PrepLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(WidgetDesign.midnight)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(context.attributes.deepLinkURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveMark()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(targetDate: context.state.targetDate)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(WidgetDesign.coral)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(title(for: context.state))
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(nextAction(for: context.state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        StatusTrack(status: context.state.status)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "sparkles")
                    .foregroundStyle(WidgetDesign.coral)
            } compactTrailing: {
                CountdownText(targetDate: context.state.targetDate)
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(WidgetDesign.coral)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "checklist")
                    .foregroundStyle(WidgetDesign.coral)
            }
            .widgetURL(context.attributes.deepLinkURL)
            .keylineTint(WidgetDesign.lavender)
        }
    }

    private func nextAction(for state: PrepActivityAttributes.ContentState) -> String {
        guard state.showsDetails else { return WidgetL10n.privateAction }
        return state.nextAction.isEmpty ? WidgetL10n.noNextAction : state.nextAction
    }

    private func title(for state: PrepActivityAttributes.ContentState) -> String {
        state.showsDetails && !state.title.isEmpty ? state.title : WidgetL10n.privatePrep
    }
}

private struct PrepLiveActivityLockScreenView: View {
    let context: ActivityViewContext<PrepActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LiveMark()
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(WidgetL10n.target)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                    CountdownText(targetDate: context.state.targetDate)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(WidgetDesign.coral)
                }
            }

            Text(context.state.showsDetails && !context.state.title.isEmpty ? context.state.title : WidgetL10n.privatePrep)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetDesign.lavender)
                Text(actionText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
            }

            StatusTrack(status: context.state.status)
        }
        .padding(16)
    }

    private var actionText: String {
        guard context.state.showsDetails else { return WidgetL10n.privateAction }
        return context.state.nextAction.isEmpty ? WidgetL10n.noNextAction : context.state.nextAction
    }
}

private struct LiveMark: View {
    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(WidgetDesign.coral.opacity(0.2))
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetDesign.coral)
            }
            .frame(width: 28, height: 28)
            Text(WidgetL10n.live)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
        }
    }
}

private struct CountdownText: View {
    let targetDate: Date

    var body: some View {
        if targetDate > .now {
            Text(timerInterval: Date.now...targetDate, countsDown: true)
                .monospacedDigit()
        } else {
            Text("00:00")
                .monospacedDigit()
        }
    }
}

private struct StatusTrack: View {
    let status: SharedPrepStatus

    var body: some View {
        HStack(spacing: 5) {
            ForEach(SharedPrepStatus.allDisplayCases, id: \.self) { candidate in
                Capsule()
                    .fill(candidate == status ? color(for: candidate) : Color.white.opacity(0.16))
                    .frame(height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetL10n.status(status))
    }

    private func color(for status: SharedPrepStatus) -> Color {
        switch status {
        case .notReady: WidgetDesign.amber
        case .inProgress: WidgetDesign.lavender
        case .ready: WidgetDesign.coral
        }
    }
}

private extension SharedPrepStatus {
    static let allDisplayCases: [SharedPrepStatus] = [.notReady, .inProgress, .ready]
}
