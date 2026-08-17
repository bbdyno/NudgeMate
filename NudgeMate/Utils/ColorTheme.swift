import SwiftUI
import UIKit

enum ColorTheme {
    static let primaryNudge = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.69, green: 0.59, blue: 0.91, alpha: 1)
                : UIColor(red: 0.36, green: 0.27, blue: 0.67, alpha: 1)
        }
    )

    static let primaryNudgeDeep = dynamicColor(
        light: (0.102, 0.133, 0.239),
        dark: (0.855, 0.824, 0.955)
    )

    static let secondarySnooze = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.61, blue: 0.53, alpha: 1)
                : UIColor(red: 0.88, green: 0.35, blue: 0.28, alpha: 1)
        }
    )

    static let background = dynamicColor(
        light: (0.984, 0.981, 0.991),
        dark: (0.047, 0.055, 0.086)
    )
    static let backgroundDeep = dynamicColor(
        light: (0.949, 0.939, 0.976),
        dark: (0.090, 0.086, 0.137)
    )
    static let cardBackground = dynamicColor(
        light: (1.000, 1.000, 1.000),
        dark: (0.090, 0.114, 0.169)
    )
    static let elevatedBackground = dynamicColor(
        light: (1.000, 1.000, 1.000),
        dark: (0.118, 0.145, 0.208)
    )
    static let primaryText = dynamicColor(
        light: (0.094, 0.129, 0.212),
        dark: (0.945, 0.957, 0.984)
    )
    static let secondaryText = dynamicColor(
        light: (0.435, 0.478, 0.565),
        dark: (0.671, 0.714, 0.804)
    )
    static let separator = dynamicColor(
        light: (0.914, 0.902, 0.935),
        dark: (0.220, 0.216, 0.294)
    )
    static let destructive = dynamicColor(
        light: (0.70, 0.20, 0.18),
        dark: (0.95, 0.48, 0.43)
    )
    static let success = dynamicColor(
        light: (0.18, 0.48, 0.43),
        dark: (0.42, 0.76, 0.68)
    )
    static let warning = dynamicColor(
        light: (0.72, 0.45, 0.15),
        dark: (0.94, 0.70, 0.39)
    )
    static let progressTrack = dynamicColor(
        light: (0.925, 0.916, 0.944),
        dark: (0.182, 0.180, 0.245)
    )
    static let brandSoft = dynamicColor(
        light: (0.944, 0.925, 0.982),
        dark: (0.188, 0.157, 0.290)
    )
    static let selectionFill = dynamicColor(
        light: (1.000, 0.922, 0.886),
        dark: (0.365, 0.176, 0.165)
    )
    static let tabBarBackdrop = dynamicColor(
        light: (1.000, 0.998, 1.000),
        dark: (0.071, 0.073, 0.106)
    )

    static let proAccent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.94, green: 0.72, blue: 0.34, alpha: 1)
                : UIColor(red: 0.72, green: 0.47, blue: 0.08, alpha: 1)
        }
    )

    static let accentCoral = dynamicColor(
        light: (0.957, 0.349, 0.286),
        dark: (1.000, 0.526, 0.459)
    )
    static let accentLavender = dynamicColor(
        light: (0.526, 0.407, 0.790),
        dark: (0.718, 0.627, 0.925)
    )
    static let accentSky = dynamicColor(
        light: (0.275, 0.560, 0.755),
        dark: (0.490, 0.730, 0.890)
    )
    static let accentAmber = dynamicColor(
        light: (0.820, 0.570, 0.180),
        dark: (0.940, 0.720, 0.340)
    )

    private static func dynamicColor(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(
            uiColor: UIColor { traits in
                let components = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: components.0,
                    green: components.1,
                    blue: components.2,
                    alpha: 1
                )
            }
        )
    }
}
