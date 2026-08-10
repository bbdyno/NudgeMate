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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                NudgeSymbolBadge(symbol: .category(event.category), size: 48)

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

            ViewThatFits(in: .horizontal) {
                actionButtons(axis: .horizontal)
                actionButtons(axis: .vertical)
            }
        }
        .padding(16)
        .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ColorTheme.separator.opacity(0.35), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: event.nextPredictedDate)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: event.isMuted)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func actionButtons(axis: Axis) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        layout {
            Button(L10n.Nudge.Action.schedule, action: onSchedule)
                .buttonStyle(.borderedProminent)
                .tint(ColorTheme.primaryNudge)
            Button(L10n.Nudge.Action.snooze, action: onSnooze)
                .buttonStyle(.bordered)
                .tint(ColorTheme.secondarySnooze)
            Menu {
                Button(L10n.Nudge.Action.skip, action: onSkip)
                    .accessibilityIdentifier("nudge.skip")
                Button(
                    event.isMuted ? L10n.Nudge.Action.enable : L10n.Nudge.Action.disable,
                    action: onToggleMute
                )
                .accessibilityIdentifier("nudge.toggleMute")
            } label: {
                Label(L10n.Common.moreActions, systemImage: "ellipsis")
            }
            .buttonStyle(.bordered)
            .tint(ColorTheme.secondaryText)
            .accessibilityIdentifier("nudge.moreActions")
        }
        .pretendard(.subheadline, weight: .semibold)
        .controlSize(.regular)
    }
}
