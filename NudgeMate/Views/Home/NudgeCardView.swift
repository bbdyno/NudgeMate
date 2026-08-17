import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct NudgeCardView: View {
    let event: RecurringEvent
    let onSchedule: () -> Void
    let onSnooze: () -> Void
    let onSkip: () -> Void
    let onToggleMute: () -> Void

    private var relativeDate: String {
        event.nextPredictedDate.formatted(.relative(presentation: .named))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                NudgeSymbolBadge(
                    symbol: .category(event.category),
                    size: NudgeLayoutMetrics.cardHeaderIconSize
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .pretendard(.headline, weight: .semibold)
                        .foregroundStyle(ColorTheme.primaryText)
                        .lineLimit(2)

                    Text(L10n.Nudge.Card.interval(event.baseInterval, relativeDate))
                        .pretendard(.subheadline)
                        .foregroundStyle(ColorTheme.secondaryText)
                }

                Spacer(minLength: 8)
            }

            NudgeCardActions(
                onSchedule: onSchedule,
                onSnooze: onSnooze,
                onSkip: onSkip,
                onToggleMute: onToggleMute,
                isMuted: event.isMuted
            )
        }
        .nudgeCardSurface()
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: event.nextPredictedDate)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: event.isMuted)
        .accessibilityElement(children: .contain)
    }
}

private struct NudgeCardActions: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onSchedule: () -> Void
    let onSnooze: () -> Void
    let onSkip: () -> Void
    let onToggleMute: () -> Void
    let isMuted: Bool

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                NudgeCardActionButton(
                    title: L10n.Nudge.Action.schedule,
                    style: .primary,
                    action: onSchedule
                )
                HStack(spacing: 8) {
                    NudgeCardActionButton(
                        title: L10n.Nudge.Action.snooze,
                        style: .secondary,
                        action: onSnooze
                    )
                    NudgeCardMoreAction(
                        isMuted: isMuted,
                        onSkip: onSkip,
                        onToggleMute: onToggleMute
                    )
                }
            }
        } else {
            HStack(spacing: 8) {
                NudgeCardActionButton(
                    title: L10n.Nudge.Action.schedule,
                    style: .primary,
                    action: onSchedule
                )
                NudgeCardActionButton(
                    title: L10n.Nudge.Action.snooze,
                    style: .secondary,
                    action: onSnooze
                )
                NudgeCardMoreAction(
                    isMuted: isMuted,
                    onSkip: onSkip,
                    onToggleMute: onToggleMute
                )
            }
        }
    }
}

private struct NudgeCardActionButton: View {
    enum Style: Equatable {
        case primary
        case secondary
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .pretendard(.caption, weight: .semibold)
                .foregroundStyle(
                    style == .primary ? ColorTheme.cardBackground : ColorTheme.secondarySnooze
                )
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    style == .primary ? ColorTheme.primaryNudge : ColorTheme.selectionFill.opacity(0.78),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            style == .primary ? Color.clear : ColorTheme.secondarySnooze.opacity(0.12),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

private struct NudgeCardMoreAction: View {
    let isMuted: Bool
    let onSkip: () -> Void
    let onToggleMute: () -> Void

    var body: some View {
        Menu {
            Button(L10n.Nudge.Action.skip, action: onSkip)
                .accessibilityIdentifier("nudge.skip")
            Button(
                isMuted ? L10n.Nudge.Action.enable : L10n.Nudge.Action.disable,
                action: onToggleMute
            )
            .accessibilityIdentifier("nudge.toggleMute")
        } label: {
            NudgeMoreActionLabel()
        }
        .accessibilityLabel(L10n.Common.moreActions)
        .accessibilityIdentifier("nudge.moreActions")
    }
}
