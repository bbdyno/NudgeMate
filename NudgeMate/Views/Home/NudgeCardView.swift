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
                SVGAssetImage(asset: .nudgeAlert)
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)

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

                Button(
                    event.isMuted ? L10n.Nudge.Action.enable : L10n.Nudge.Action.disable,
                    action: onToggleMute
                )
                    .pretendard(.caption, weight: .medium)
                    .buttonStyle(.borderless)
                    .foregroundStyle(ColorTheme.secondaryText)
            }

            HStack(spacing: 10) {
                Button(L10n.Nudge.Action.schedule, action: onSchedule)
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTheme.primaryNudge)

                Button(L10n.Nudge.Action.snooze, action: onSnooze)
                    .buttonStyle(.bordered)
                    .tint(ColorTheme.secondarySnooze)

                Button(L10n.Nudge.Action.skip, action: onSkip)
                    .buttonStyle(.borderless)
                    .foregroundStyle(ColorTheme.secondaryText)
            }
            .pretendard(.subheadline, weight: .semibold)
            .controlSize(.regular)
        }
        .padding(16)
        .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ColorTheme.separator.opacity(0.35), lineWidth: 0.5)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: event.nextPredictedDate)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: event.isMuted)
        .accessibilityElement(children: .contain)
    }
}
