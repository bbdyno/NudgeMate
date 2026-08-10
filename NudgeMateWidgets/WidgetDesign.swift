import SwiftUI

enum WidgetDesign {
    static let ink = Color(red: 0.08, green: 0.12, blue: 0.18)
    static let secondaryInk = Color(red: 0.36, green: 0.37, blue: 0.42)
    static let lavender = Color(red: 0.54, green: 0.50, blue: 0.72)
    static let lavenderSoft = Color(red: 0.90, green: 0.86, blue: 0.94)
    static let coral = Color(red: 0.89, green: 0.48, blue: 0.38)
    static let amber = Color(red: 0.82, green: 0.61, blue: 0.23)
    static let cream = Color(red: 0.99, green: 0.98, blue: 0.96)
    static let midnight = Color(red: 0.055, green: 0.075, blue: 0.105)
}

enum WidgetL10n {
    static var title: String { text("widget.title") }
    static var upNext: String { text("widget.upNext") }
    static var emptyTitle: String { text("widget.empty.title") }
    static var emptyMessage: String { text("widget.empty.message") }
    static var openApp: String { text("widget.openApp") }
    static var nextAction: String { text("widget.nextAction") }
    static var privatePrep: String { text("widget.privatePrep") }
    static var live: String { text("liveActivity.live") }
    static var target: String { text("liveActivity.target") }
    static var noNextAction: String { text("liveActivity.noNextAction") }
    static var privateAction: String { text("liveActivity.privateAction") }

    static func more(_ count: Int) -> String {
        String(format: text("widget.more"), count)
    }

    static func status(_ status: SharedPrepStatus) -> String {
        switch status {
        case .notReady: text("status.notReady")
        case .inProgress: text("status.inProgress")
        case .ready: text("status.ready")
        }
    }

    private static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
}
