import Foundation

enum LoginImportService {
    static func decode(_ data: Data) throws -> [BiliAccount] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], !json.isEmpty else {
            throw AccountStorageError.invalidAccount
        }
        return try json.keys.sorted().map { key in
            guard let user = json[key] as? [String: Any], let cookie = user["cookies"] as? [String: Any],
                  let sessdata = cookie["SESSDATA"] as? String, !sessdata.isEmpty,
                  let csrf = cookie["bili_jct"] as? String, !csrf.isEmpty,
                  let uid = cookie["DedeUserID"] as? String, uid == key, UInt64(uid).map({ $0 > 0 }) == true
            else { throw AccountStorageError.invalidAccount }
            return BiliAccount(cookies: BiliCookie(SESSDATA: sessdata, bili_jct: csrf, DedeUserID: uid,
                sid: cookie["sid"] as? String, buvid3: cookie["buvid3"] as? String),
                accessKey: user["accessKey"] as? String, refresh: user["refresh"] as? String, type: user["type"] as? [Int])
        }
    }
    static func importFrom(url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        try LoginSession.shared.add(decode(Data(contentsOf: url)))
    }
    static func restore() { LoginSession.shared.restore() }
    static func clearLoginState() throws {
        let id = LoginSession.shared.selectedID(for: .main)
        if id != "0" { try LoginSession.shared.remove(id) }
    }
}
