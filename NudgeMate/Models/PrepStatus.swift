import Foundation

private typealias L10n = NudgeMateStrings.Localizable

enum PrepStatus: String, Codable, CaseIterable, Identifiable {
    case notReady
    case inProgress
    case ready

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .notReady:
            return L10n.Prep.Status.notReady
        case .inProgress:
            return L10n.Prep.Status.inProgress
        case .ready:
            return L10n.Prep.Status.ready
        }
    }
}
