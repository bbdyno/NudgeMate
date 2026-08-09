import SwiftUI
import UIKit

enum ColorTheme {
    static let primaryNudge = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.48, green: 0.64, blue: 1.00, alpha: 1)
                : UIColor(red: 0.18, green: 0.36, blue: 0.88, alpha: 1)
        }
    )

    static let secondarySnooze = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.37, green: 0.82, blue: 0.75, alpha: 1)
                : UIColor(red: 0.05, green: 0.51, blue: 0.46, alpha: 1)
        }
    )

    static let background = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)
    static let destructive = Color(uiColor: .systemRed)
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let progressTrack = Color(uiColor: .tertiarySystemFill)

    static let proAccent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.94, green: 0.72, blue: 0.34, alpha: 1)
                : UIColor(red: 0.66, green: 0.40, blue: 0.04, alpha: 1)
        }
    )
}
