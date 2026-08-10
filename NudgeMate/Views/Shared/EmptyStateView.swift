import SwiftUI

struct EmptyStateView: View {
    let icon: NudgeSymbol
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: NudgeSymbol,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            NudgeSymbolBadge(symbol: icon, size: 112)

            Text(title)
                .pretendard(.title2, weight: .semibold)
                .foregroundStyle(ColorTheme.primaryText)
                .multilineTextAlignment(.center)

            Text(message)
                .pretendard(.body)
                .foregroundStyle(ColorTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .pretendard(.headline, weight: .semibold)
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTheme.primaryNudge)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: 420)
        .padding(24)
        .accessibilityElement(children: .contain)
    }
}
