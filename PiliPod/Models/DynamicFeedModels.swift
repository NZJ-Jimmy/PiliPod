import Foundation

enum DynamicCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case video = "投稿"
    case pgc = "番剧"
    case article = "专栏"

    var id: String { rawValue }

    var apiType: String {
        switch self {
        case .all: return "all"
        case .video: return "video"
        case .pgc: return "pgc"
        case .article: return "article"
        }
    }

    // 无已验证的 UP + 投稿/番剧组合接口时，按顶层类型筛选，避免将转发算作投稿。
    func matches(_ item: UserSpaceDynamicItem) -> Bool {
        switch self {
        case .all: return true
        case .video: return item.type == "DYNAMIC_TYPE_AV"
        case .pgc: return item.type == "DYNAMIC_TYPE_PGC" || item.type == "DYNAMIC_TYPE_PGC_UNION"
        case .article: return item.type == "DYNAMIC_TYPE_ARTICLE"
        }
    }
}

struct DynamicFeedFilter: Hashable {
    var category: DynamicCategory = .all
    var authorMID: Int?

    var needsLocalCategoryFilter: Bool {
        authorMID != nil && (category == .video || category == .pgc)
    }

    var automaticPageLimit: Int { needsLocalCategoryFilter ? 2 : 1 }

    func requestURL(offset: String? = nil) -> URL {
        let isAuthorArticle = authorMID != nil && category == .article
        let path = isAuthorArticle ? "opus/feed/space" : "feed/all"
        var components = URLComponents(string: "https://api.bilibili.com/x/polymer/web-dynamic/v1/\(path)")!
        var query = [URLQueryItem(name: "platform", value: "web"),
                     URLQueryItem(name: "web_location", value: isAuthorArticle ? "333.1387" : "333.1365")]
        if let authorMID {
            query.append(URLQueryItem(name: "host_mid", value: String(authorMID)))
            if isAuthorArticle { query.append(URLQueryItem(name: "type", value: "article")) }
        } else {
            query.append(URLQueryItem(name: "type", value: category.apiType))
        }
        if let offset, !offset.isEmpty { query.append(URLQueryItem(name: "offset", value: offset)) }
        if !isAuthorArticle {
            query.append(URLQueryItem(name: "features", value: "itemOpusStyle,listOnlyfans,opusBigCover,onlyfansVote,forwardListHidden,decorationCard,commentsNewVersion,onlyfansAssetsV2,ugcDelete,onlyfansQaCard"))
        }
        components.queryItems = query
        return components.url!
    }
}

struct DynamicFeedAuthor: Decodable, Identifiable, Hashable {
    let mid: Int
    let uname: String
    let face: String?
    let hasUpdate: Bool?

    var id: Int { mid }

    enum CodingKeys: String, CodingKey {
        case mid, uname, face
        case hasUpdate = "has_update"
    }
}

struct DynamicPortalResponse: Decodable {
    let code: Int
    let message: String?
    let data: Payload?

    struct Payload: Decodable {
        let upList: UPList?
        enum CodingKeys: String, CodingKey { case upList = "up_list" }
    }

    struct UPList: Decodable {
        let items: [DynamicFeedAuthor]?
    }
}
