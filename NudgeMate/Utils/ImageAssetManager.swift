import SwiftUI

enum ImageAssetManager {
    enum Asset: String, CaseIterable {
        case calendarIcon = "calendar_icon"
        case nudgeAlert = "nudge_alert"
        case emptyState = "empty_state"
        case paywallHero = "paywall_hero"
        case featureCheck = "feature_check"
        case sync = "sync"
        case proBadge = "pro_badge"
    }

    static func svg(named asset: Asset) -> String {
        inlineSVGs[asset] ?? ""
    }

    static func data(named asset: Asset) -> Data? {
        svg(named: asset).data(using: .utf8)
    }

    static func base64EncodedSVG(named asset: Asset) -> String {
        data(named: asset)?.base64EncodedString() ?? ""
    }

    static func dataURL(named asset: Asset) -> URL? {
        URL(string: "data:image/svg+xml;base64,\(base64EncodedSVG(named: asset))")
    }

    private static let inlineSVGs: [Asset: String] = [
        .calendarIcon: """
        <svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96" fill="none">
          <rect x="11" y="18" width="74" height="67" rx="15" fill="#E9EEFF" stroke="#315CDA" stroke-width="6"/>
          <path d="M14 39H82" stroke="#315CDA" stroke-width="6" stroke-linecap="round"/>
          <path d="M30 11V27M66 11V27" stroke="#315CDA" stroke-width="7" stroke-linecap="round"/>
          <rect x="27" y="51" width="12" height="12" rx="4" fill="#315CDA"/>
          <rect x="47" y="51" width="12" height="12" rx="4" fill="#71CFC0"/>
          <rect x="27" y="68" width="12" height="9" rx="4" fill="#71CFC0"/>
          <rect x="47" y="68" width="12" height="9" rx="4" fill="#315CDA"/>
          <rect x="67" y="51" width="10" height="12" rx="4" fill="#315CDA" opacity=".45"/>
        </svg>
        """,
        .nudgeAlert: """
        <svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96" fill="none">
          <path d="M48 10C29.8 10 15 24.8 15 43V57.5L9 69C7.8 71.4 9.5 74 12.2 74H83.8C86.5 74 88.2 71.4 87 69L81 57.5V43C81 24.8 66.2 10 48 10Z" fill="#E9EEFF" stroke="#315CDA" stroke-width="6" stroke-linejoin="round"/>
          <path d="M36 78C38.4 84.5 42.4 88 48 88C53.6 88 57.6 84.5 60 78" stroke="#315CDA" stroke-width="6" stroke-linecap="round"/>
          <path d="M48 31V48" stroke="#0D8275" stroke-width="7" stroke-linecap="round"/>
          <circle cx="48" cy="60" r="4.5" fill="#0D8275"/>
        </svg>
        """,
        .emptyState: """
        <svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128" fill="none">
          <path d="M27 24H84C94.5 24 103 32.5 103 43V96C103 106.5 94.5 115 84 115H27C16.5 115 8 106.5 8 96V43C8 32.5 16.5 24 27 24Z" fill="#F1F4FF" stroke="#315CDA" stroke-width="7"/>
          <path d="M31 11V36M80 11V36M12 50H99" stroke="#315CDA" stroke-width="7" stroke-linecap="round"/>
          <circle cx="96" cy="91" r="25" fill="#D8F4EF" stroke="#0D8275" stroke-width="7"/>
          <path d="M86 91L93 98L107 82" stroke="#0D8275" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M27 65H50M27 80H45" stroke="#93A8E8" stroke-width="7" stroke-linecap="round"/>
        </svg>
        """,
        .paywallHero: """
        <svg xmlns="http://www.w3.org/2000/svg" width="160" height="128" viewBox="0 0 160 128" fill="none">
          <path d="M31 102C17 88 15 65 26 48C39 27 64 18 87 25C104 13 129 20 138 39C147 57 140 78 124 88C112 107 91 116 70 111C55 116 41 112 31 102Z" fill="#E9EEFF"/>
          <path d="M80 16L91 43L120 45L98 64L105 92L80 77L55 92L62 64L40 45L69 43L80 16Z" fill="#F3BD55" stroke="#315CDA" stroke-width="6" stroke-linejoin="round"/>
          <path d="M80 48V65" stroke="#315CDA" stroke-width="7" stroke-linecap="round"/>
          <circle cx="80" cy="74" r="4" fill="#315CDA"/>
          <path d="M29 27L34 36M128 100L136 108M132 23L124 32M25 96L17 104" stroke="#0D8275" stroke-width="6" stroke-linecap="round"/>
        </svg>
        """,
        .featureCheck: """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none">
          <rect x="5" y="5" width="54" height="54" rx="18" fill="#D8F4EF" stroke="#0D8275" stroke-width="5"/>
          <path d="M19 32L28 41L46 22" stroke="#0D8275" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        """,
        .sync: """
        <svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80" fill="none">
          <path d="M62 31C58 20 48 14 37 15C27 16 19 22 15 31" stroke="#315CDA" stroke-width="7" stroke-linecap="round"/>
          <path d="M53 29L63 32L67 21" stroke="#315CDA" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M18 49C22 60 32 66 43 65C53 64 61 58 65 49" stroke="#0D8275" stroke-width="7" stroke-linecap="round"/>
          <path d="M27 51L17 48L13 59" stroke="#0D8275" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        """,
        .proBadge: """
        <svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80" fill="none">
          <path d="M12 25L25 34L40 14L55 34L68 25L61 61H19L12 25Z" fill="#F3BD55" stroke="#8E5A09" stroke-width="6" stroke-linejoin="round"/>
          <path d="M23 51H57" stroke="#8E5A09" stroke-width="6" stroke-linecap="round"/>
        </svg>
        """
    ]
}

struct SVGAssetImage: View {
    let asset: ImageAssetManager.Asset

    var body: some View {
        Image(asset.rawValue)
            .resizable()
            .scaledToFit()
    }
}
