import SwiftUI
import UIKit

enum ColorTheme {
    static let primaryNudge = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.74, green: 0.70, blue: 0.89, alpha: 1)
                : UIColor(red: 0.13, green: 0.20, blue: 0.29, alpha: 1)
        }
    )

    static let secondarySnooze = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.94, green: 0.52, blue: 0.43, alpha: 1)
                : UIColor(red: 0.68, green: 0.29, blue: 0.24, alpha: 1)
        }
    )

    static let background = dynamicColor(
        light: (0.972, 0.953, 0.925),
        dark: (0.055, 0.075, 0.105)
    )
    static let backgroundDeep = dynamicColor(
        light: (0.925, 0.906, 0.945),
        dark: (0.090, 0.105, 0.150)
    )
    static let cardBackground = dynamicColor(
        light: (0.997, 0.990, 0.978),
        dark: (0.105, 0.125, 0.170)
    )
    static let elevatedBackground = dynamicColor(
        light: (1.000, 0.998, 0.992),
        dark: (0.135, 0.155, 0.210)
    )
    static let primaryText = dynamicColor(
        light: (0.080, 0.120, 0.180),
        dark: (0.940, 0.930, 0.910)
    )
    static let secondaryText = dynamicColor(
        light: (0.360, 0.370, 0.420),
        dark: (0.680, 0.680, 0.730)
    )
    static let separator = dynamicColor(
        light: (0.780, 0.760, 0.800),
        dark: (0.250, 0.250, 0.330)
    )
    static let destructive = dynamicColor(
        light: (0.70, 0.20, 0.18),
        dark: (0.95, 0.48, 0.43)
    )
    static let success = dynamicColor(
        light: (0.16, 0.44, 0.48),
        dark: (0.40, 0.73, 0.76)
    )
    static let warning = dynamicColor(
        light: (0.72, 0.45, 0.15),
        dark: (0.94, 0.70, 0.39)
    )
    static let progressTrack = dynamicColor(
        light: (0.865, 0.835, 0.890),
        dark: (0.185, 0.190, 0.265)
    )
    static let brandSoft = dynamicColor(
        light: (0.900, 0.860, 0.940),
        dark: (0.205, 0.185, 0.285)
    )
    static let selectionFill = dynamicColor(
        light: (0.965, 0.855, 0.815),
        dark: (0.300, 0.190, 0.205)
    )
    static let tabBarBackdrop = dynamicColor(
        light: (0.960, 0.945, 0.935),
        dark: (0.070, 0.090, 0.125)
    )

    static let proAccent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.94, green: 0.72, blue: 0.34, alpha: 1)
                : UIColor(red: 0.72, green: 0.47, blue: 0.08, alpha: 1)
        }
    )

    static let accentCoral = dynamicColor(
        light: (0.89, 0.48, 0.38),
        dark: (0.94, 0.56, 0.47)
    )
    static let accentLavender = dynamicColor(
        light: (0.54, 0.50, 0.72),
        dark: (0.72, 0.68, 0.88)
    )
    static let accentSky = dynamicColor(
        light: (0.35, 0.59, 0.70),
        dark: (0.46, 0.69, 0.79)
    )
    static let accentAmber = dynamicColor(
        light: (0.82, 0.61, 0.23),
        dark: (0.91, 0.70, 0.33)
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
