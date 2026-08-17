import CryptoKit
import Foundation

struct BundleIDsResponse: Decodable {
    struct Resource: Decodable {
        struct Attributes: Decodable { let identifier: String }
        let id: String
        let attributes: Attributes
    }
    let data: [Resource]
}

struct ProfilesResponse: Decodable {
    struct Resource: Decodable {
        struct Attributes: Decodable {
            let name: String
            let profileContent: String
            let profileState: String
            let profileType: String
            let uuid: String
            let expirationDate: Date
        }

        let id: String
        let attributes: Attributes
    }

    let data: [Resource]
}

enum DownloadError: LocalizedError {
    case usage
    case missingBundleID
    case missingActiveProfile
    case invalidResponse(Int, String)
    case invalidProfileContent

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: download_app_store_profile.swift <issuer-id> <key-id> <key-path> <bundle-id> <output-path>"
        case .missingBundleID:
            return "The requested bundle ID is not registered."
        case .missingActiveProfile:
            return "No active iOS App Store provisioning profile was found."
        case let .invalidResponse(status, body):
            return "App Store Connect API returned HTTP \(status): \(body)"
        case .invalidProfileContent:
            return "The provisioning profile content was not valid Base64 data."
        }
    }
}

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func makeToken(issuerID: String, keyID: String, keyPath: String) throws -> String {
    let privateKey = try P256.Signing.PrivateKey(
        pemRepresentation: String(contentsOfFile: keyPath, encoding: .utf8)
    )
    let now = Int(Date().timeIntervalSince1970)
    let header = try JSONSerialization.data(withJSONObject: [
        "alg": "ES256",
        "kid": keyID,
        "typ": "JWT",
    ])
    let payload = try JSONSerialization.data(withJSONObject: [
        "iss": issuerID,
        "iat": now,
        "exp": now + 1_200,
        "aud": "appstoreconnect-v1",
    ])
    let unsignedToken = "\(base64URL(header)).\(base64URL(payload))"
    let signature = try privateKey.signature(for: Data(unsignedToken.utf8))
    return "\(unsignedToken).\(base64URL(signature.rawRepresentation))"
}

func request<T: Decodable>(_ type: T.Type, url: URL, token: String) async throws -> T {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard 200..<300 ~= status else {
        throw DownloadError.invalidResponse(status, String(decoding: data, as: UTF8.self))
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(type, from: data)
}

@main
struct Main {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 6 else { throw DownloadError.usage }

        let token = try makeToken(
            issuerID: arguments[1],
            keyID: arguments[2],
            keyPath: arguments[3]
        )
        let bundleIdentifier = arguments[4]
        let outputPath = arguments[5]

        var bundleURL = URLComponents(string: "https://api.appstoreconnect.apple.com/v1/bundleIds")!
        bundleURL.queryItems = [URLQueryItem(name: "filter[identifier]", value: bundleIdentifier)]
        let bundles = try await request(BundleIDsResponse.self, url: bundleURL.url!, token: token)
        guard let bundleID = bundles.data.first(where: {
            $0.attributes.identifier == bundleIdentifier
        })?.id else {
            throw DownloadError.missingBundleID
        }

        var profilesURL = URLComponents(
            string: "https://api.appstoreconnect.apple.com/v1/bundleIds/\(bundleID)/profiles"
        )!
        profilesURL.queryItems = [
            URLQueryItem(name: "limit", value: "200"),
        ]
        let profiles = try await request(ProfilesResponse.self, url: profilesURL.url!, token: token)
        guard let profile = profiles.data
            .filter({
                $0.attributes.profileState == "ACTIVE"
                    && $0.attributes.profileType == "IOS_APP_STORE"
            })
            .max(by: { $0.attributes.expirationDate < $1.attributes.expirationDate })
        else {
            throw DownloadError.missingActiveProfile
        }
        guard let content = Data(base64Encoded: profile.attributes.profileContent) else {
            throw DownloadError.invalidProfileContent
        }

        try content.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        print("Downloaded \(profile.attributes.name) (\(profile.attributes.uuid)) to \(outputPath)")
    }
}
