import Foundation

enum PrepWidgetSnapshotStore {
    static func load(defaults: UserDefaults? = sharedDefaults) -> PrepWidgetSnapshot {
        guard let defaults,
              let data = defaults.data(forKey: NudgeMateSharedConfiguration.snapshotDefaultsKey),
              let snapshot = try? decoder.decode(PrepWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    @discardableResult
    static func save(
        _ snapshot: PrepWidgetSnapshot,
        defaults: UserDefaults? = sharedDefaults
    ) -> Bool {
        guard let defaults, let data = try? encoder.encode(snapshot) else { return false }
        defaults.set(data, forKey: NudgeMateSharedConfiguration.snapshotDefaultsKey)
        return true
    }

    static func clear(defaults: UserDefaults? = sharedDefaults) {
        defaults?.removeObject(forKey: NudgeMateSharedConfiguration.snapshotDefaultsKey)
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: NudgeMateSharedConfiguration.appGroupIdentifier)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}
