import SwiftUI

struct EmptyStateView: View {
    let icon: ImageAssetManager.Asset
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: ImageAssetManager.Asset,
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
            SVGAssetImage(asset: icon)
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)

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
