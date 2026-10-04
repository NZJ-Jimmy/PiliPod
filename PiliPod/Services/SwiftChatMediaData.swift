import Foundation

enum SwiftChatMediaData {
    static func read(_ url: URL) async throws -> Data {
        if url.isFileURL { return try await Task.detached { try Data(contentsOf: url) }.value }
        if url.scheme == "data" {
            let value = url.absoluteString
            guard let separator = value.firstIndex(of: ",") else { throw APIError.requestFailed }
            let header = value[..<separator]
            let payload = String(value[value.index(after: separator)...])
            guard header.hasPrefix("data:image/"), header.hasSuffix(";base64"),
                  let data = Data(base64Encoded: payload.removingPercentEncoding ?? payload) else {
                throw APIError.businessError(code: -400, message: "无法读取所选图片")
            }
            return data
        }
        guard url.scheme == "https" else { throw APIError.requestFailed }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw APIError.requestFailed
        }
        return data
    }
}
