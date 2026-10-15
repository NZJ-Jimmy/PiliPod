import Foundation

struct LibraryEnvelope<Value: Decodable>: Decodable {
    let code: Int
    let message: String?
    let data: Value?
}

struct LibraryFolder: Decodable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let cover: String?
    let upper: LibraryOwner?
    let mediaCount: Int?
    let type: Int?
    let state: Int?
    let attr: Int?
    let intro: String?

    var isCollection: Bool { type == 21 }
    var isUnavailable: Bool { state == 1 }
    var kindLabel: String {
        switch type {
        case 21: return "合集"
        case nil, 11: return "收藏夹"
        default: return "其他订阅"
        }
    }
    var isPrivate: Bool { ((attr ?? 0) & 1) == 1 }

    enum CodingKeys: String, CodingKey {
        case id, title, cover, upper, type, state, attr, intro
        case mediaCount = "media_count"
    }
}

struct LibraryOwner: Decodable, Hashable {
    let name: String?
}

struct LibraryFolderData: Decodable {
    let count: Int?
    let hasMore: Bool?
    let list: [LibraryFolder]?

    enum CodingKeys: String, CodingKey {
        case count, list
        case hasMore = "has_more"
    }
}

struct LibraryMediaData: Decodable {
    let info: LibraryFolder?
    let hasMore: Bool?
    let medias: [LibraryMedia]?

    enum CodingKeys: String, CodingKey {
        case info, medias
        case hasMore = "has_more"
    }
}

struct LibraryMedia: Decodable, Identifiable {
    let id: Int64
    let title: String?
    let cover: String?
    let duration: Int?
    let upper: LibraryOwner?
    let attr: Int?
    let type: Int?
    let bvid: String?
    let pubtime: Int?
    let cntInfo: Counts?

    struct Counts: Decodable {
        let play: Int?
        let danmaku: Int?
    }

    // Invalid and non-video resources remain visible without opening the player.
    var video: VideoItem? {
        guard ((attr ?? 0) & 9) == 0, type == nil || type == 2,
              let bvid, !bvid.isEmpty else { return nil }
        return displayVideo
    }

    // Keep metadata and the standard card geometry even when playback is unavailable.
    var displayVideo: VideoItem {
        return VideoItem(
            bvid: bvid ?? "library-unavailable-\(id)", cid: nil,
            cover: (cover ?? "").replacingOccurrences(of: "http://", with: "https://"),
            title: title ?? (bvid == nil ? "已失效视频" : "未命名视频"),
            playCount: cntInfo?.play.map(VideoItem.formatCount) ?? "--",
            danmakuCount: cntInfo?.danmaku.map(VideoItem.formatCount) ?? "--",
            uploader: upper?.name ?? "", duration: duration ?? 0,
            progressSeconds: nil, publishTimeText: VideoItem.formatTimestamp(pubtime),
            bottomRcmdReasonText: nil
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, title, cover, duration, upper, attr, type, bvid, pubtime
        case legacyBvid = "bv_id"
        case cntInfo = "cnt_info"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        cover = try c.decodeIfPresent(String.self, forKey: .cover)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
        upper = try c.decodeIfPresent(LibraryOwner.self, forKey: .upper)
        attr = try c.decodeIfPresent(Int.self, forKey: .attr)
        type = try c.decodeIfPresent(Int.self, forKey: .type)
        bvid = try c.decodeIfPresent(String.self, forKey: .bvid)
            ?? c.decodeIfPresent(String.self, forKey: .legacyBvid)
        pubtime = try c.decodeIfPresent(Int.self, forKey: .pubtime)
        cntInfo = try c.decodeIfPresent(Counts.self, forKey: .cntInfo)
    }
}

struct LibraryPage<Entry> {
    let entries: [Entry]
    let hasMore: Bool
}
