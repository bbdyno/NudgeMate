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
        VStack(spacing: 14) {
            NudgeSymbolBadge(symbol: icon, size: 96)

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
                Button(action: action) {
                    Text(actionTitle)
                        .pretendard(.headline, weight: .semibold)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 48)
                }
                    .buttonStyle(NudgePrimaryButtonStyle())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: 420)
        .padding(20)
        .accessibilityElement(children: .contain)
    }
}
