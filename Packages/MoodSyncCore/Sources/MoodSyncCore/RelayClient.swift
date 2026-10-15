import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum RelayEndpoint {
    public static func url(base: String, path: String, auth: String) throws -> URL {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !SyncConfiguration.isPlaceholder(trimmed) else {
            throw SyncError.notConfigured
        }
        guard var components = URLComponents(string: trimmed),
              components.scheme == "https" || components.scheme == "http",
              components.host != nil else {
            throw SyncError.invalidURL
        }
        let extra = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let existing = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if existing.isEmpty {
            components.path = "/" + extra
        } else {
            components.path = "/" + existing + "/" + extra
        }
        let token = auth.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "auth", value: token))
            components.queryItems = items
        }
        guard let url = components.url else {
            throw SyncError.invalidURL
        }
        return url
    }

    public static func circlePath(_ code: String) -> String {
        "moodsync/circles/\(code).json"
    }

    public static func namePath(_ code: String) -> String {
        "moodsync/circles/\(code)/name.json"
    }

    public static func memberPath(code: String, userID: UUID) -> String {
        "moodsync/circles/\(code)/members/\(userID.uuidString).json"
    }
}

public struct RelayClient {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(session: URLSession = RelayClient.makeSession()) {
        self.session = session
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }

    public func publishName(circle: FriendCircle, settings: SyncSettings, auth: String) async throws {
        let url = try RelayEndpoint.url(base: settings.relayURL, path: RelayEndpoint.namePath(circle.inviteCode), auth: auth)
        let body = try encoder.encode(circle.name)
        try await send(url: url, method: "PUT", body: body)
    }

    public func publishMember(circle: FriendCircle, settings: SyncSettings, auth: String) async throws {
        guard let me = circle.members.first(where: { $0.isCurrentUser }),
              let payload = RemoteMember.from(member: me) else {
            return
        }
        let url = try RelayEndpoint.url(
            base: settings.relayURL,
            path: RelayEndpoint.memberPath(code: circle.inviteCode, userID: me.id),
            auth: auth
        )
        try await send(url: url, method: "PUT", body: try encoder.encode(payload))
    }

    public func fetchCircle(code: String, settings: SyncSettings, auth: String) async throws -> RemoteCircle {
        let url = try RelayEndpoint.url(base: settings.relayURL, path: RelayEndpoint.circlePath(code), auth: auth)
        let data = try await send(url: url, method: "GET", body: nil)
        return try decodeCircle(data)
    }

    public func decodeCircle(_ data: Data) throws -> RemoteCircle {
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty || text == "null" {
            return RemoteCircle(name: nil, members: [])
        }
        let dto = try decoder.decode(CircleDTO.self, from: data)
        let people = (dto.members ?? [:]).compactMap { key, value -> RemotePerson? in
            guard let id = UUID(uuidString: key) else { return nil }
            guard !value.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return RemotePerson(id: id, member: value)
        }
        return RemoteCircle(name: dto.name, members: people)
    }

    @discardableResult
    private func send(url: URL, method: String, body: Data?) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.server("The relay didn't answer.")
        }
        guard (200...299).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let clipped = snippet.count > 180 ? String(snippet.prefix(180)) + "…" : snippet
            if clipped.isEmpty {
                throw SyncError.server("The relay replied \(http.statusCode).")
            }
            throw SyncError.server("The relay replied \(http.statusCode). \(clipped)")
        }
        return data
    }
}

private struct CircleDTO: Decodable {
    var name: String?
    var members: [String: RemoteMember]?
}
