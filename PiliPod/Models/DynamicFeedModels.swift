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

    // 空间动态接口不支持类别参数，按顶层类型筛选，避免将转发中的视频算作投稿。
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
