import Foundation

struct LibraryService {
    static let pageSize = 20

    static func folders(subscriptions: Bool, page: Int) async throws -> LibraryPage<LibraryFolder> {
        guard let mid = LoginSession.shared.cookies?.DedeUserID else {
            throw LibraryError.loginRequired
        }
        let data: LibraryFolderData = try await get(
            subscriptions ? "/x/v3/fav/folder/collected/list" : "/x/v3/fav/folder/created/list",
            parameters: ["up_mid": mid, "pn": String(page), "ps": String(pageSize), "platform": "web"]
        )
        let entries = data.list ?? []
        return LibraryPage(entries: entries, hasMore: data.hasMore ?? (page * pageSize < (data.count ?? 0)))
    }

    static func media(folder: LibraryFolder, page: Int) async throws -> LibraryPage<LibraryMedia> {
        let data: LibraryMediaData = try await get(
            folder.isCollection ? "/x/space/fav/season/list" : "/x/v3/fav/resource/list",
            parameters: [
                folder.isCollection ? "season_id" : "media_id": String(folder.id),
                "pn": String(page), "ps": String(pageSize), "platform": "web", "order": "mtime", "type": "0", "tid": "0"
            ]
        )
        let entries = data.medias ?? []
        let hasMore = data.hasMore ?? (page * pageSize < (data.info?.mediaCount ?? folder.mediaCount ?? 0))
        return LibraryPage(entries: entries, hasMore: hasMore)
    }

    static func unsubscribe(_ folder: LibraryFolder) async throws {
        guard folder.type == 11 || folder.type == 21 else { throw LibraryError.unsupported }
        guard let csrf = LoginSession.shared.cookies?.bili_jct else { throw LibraryError.loginRequired }
        let path = folder.isCollection ? "/x/v3/fav/season/unfav" : "/x/v3/fav/folder/unfav"
        var request = try request(path: path)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: folder.isCollection ? "season_id" : "media_id", value: String(folder.id)),
            URLQueryItem(name: "csrf", value: csrf),
            URLQueryItem(name: "platform", value: "web")
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        let envelope = try JSONDecoder().decode(LibraryEnvelope<LibraryMutation>.self, from: data)
        guard envelope.code == 0 else { throw LibraryError.server(envelope.message ?? "请求失败", envelope.code) }
    }

    private static func get<Value: Decodable>(_ path: String, parameters: [String: String]) async throws -> Value {
        let request = try request(path: path, parameters: parameters)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        let envelope = try JSONDecoder().decode(LibraryEnvelope<Value>.self, from: data)
        guard envelope.code == 0 else { throw LibraryError.server(envelope.message ?? "请求失败", envelope.code) }
        guard let value = envelope.data else { throw LibraryError.missingData }
        return value
    }

    private static func request(path: String, parameters: [String: String] = [:]) throws -> URLRequest {
        guard LoginSession.shared.isLogin else { throw LibraryError.loginRequired }
        var components = URLComponents(string: "https://api.bilibili.com" + path)
        components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(LoginSession.shared.cookieString, forHTTPHeaderField: "Cookie")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

private struct LibraryMutation: Decodable {}

enum LibraryError: LocalizedError {
    case loginRequired, missingData, unsupported
    case server(String, Int)

    var errorDescription: String? {
        switch self {
        case .loginRequired: return "请先登录后查看"
        case .missingData: return "服务器未返回数据，请重试"
        case .unsupported: return "暂不支持此订阅类型"
        case let .server(message, code): return "\(message)（\(code)）"
        }
    }
}
