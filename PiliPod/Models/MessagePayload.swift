import Foundation

struct MessagePayload {
    static func dictionary(from raw: String) -> [String: Any]? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func url(from raw: String) -> URL? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("//") {
            value = "https:" + value
        } else if value.hasPrefix("http://") {
            value = "https://" + value.dropFirst("http://".count)
        }
        return URL(string: value)
    }

    static func text(from message: Bilibili_Im_Type_Msg) -> String {
        let raw = message.content
        guard let dictionary = dictionary(from: raw) else { return raw }

        if message.msgType.rawValue == 18,
           let nestedContent = dictionary["content"] as? String,
           let nestedData = nestedContent.data(using: .utf8),
           let items = try? JSONSerialization.jsonObject(with: nestedData) as? [[String: Any]]
        {
            let text = items.compactMap { $0["text"] as? String }
                .joined(separator: "\n")
            if !text.isEmpty { return text }
        }

        if let value = dictionary["content"] as? String { return value }
        if let value = dictionary["text"] as? String { return value }
        if let value = dictionary["title"] as? String { return value }
        if message.msgType.rawValue == 2 || message.msgType.rawValue == 6 {
            return "[图片]"
        }
        return raw
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let value as String where !value.isEmpty:
            value
        case let value as NSNumber:
            value.stringValue
        default:
            nil
        }
    }

    static func int(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            value
        case let value as NSNumber:
            value.intValue
        case let value as String:
            Int(value)
        default:
            nil
        }
    }
}

struct MessageCardPayload {
    enum Kind { case video, article, other }

    let kind: Kind
    let title: String
    let summary: String
    let author: String
    let coverURL: String
    let bvid: String?
    let duration: Int
    let isUserVideoShare: Bool

    init?(message: Bilibili_Im_Type_Msg) {
        let type = message.msgType.rawValue
        guard type == 7 || type == 11 || type == 12 || type == 14,
              let dictionary = MessagePayload.dictionary(from: message.content)
        else { return nil }

        let source = MessagePayload.int(dictionary["source"])
        isUserVideoShare = type == 7 && source == 5
        if type == 11 || (type == 7 && source == 5) {
            kind = .video
        } else if type == 12 || (type == 7 && source == 6) {
            kind = .article
        } else {
            kind = .other
        }

        title = (dictionary["title"] as? String)
            ?? (dictionary["headline"] as? String)
            ?? (dictionary["desc"] as? String)
            ?? "分享内容"
        summary = (dictionary["summary"] as? String)
            ?? (dictionary["desc"] as? String)
            ?? ""
        author = MessagePayload.string(dictionary["uname"])
            ?? MessagePayload.string(dictionary["author"])
            ?? ""
        coverURL = MessagePayload.string(dictionary["cover"])
            ?? MessagePayload.string(dictionary["thumb"])
            ?? ((dictionary["image_urls"] as? [String])?.first ?? "")
        bvid = MessagePayload.string(dictionary["bvid"])
        duration = MessagePayload.int(dictionary["duration"])
            ?? MessagePayload.int(dictionary["times"])
            ?? 0
    }

    var videoItem: VideoItem? {
        guard kind == .video, let bvid else { return nil }
        return VideoItem(
            bvid: bvid,
            cid: nil,
            cover: coverURL,
            title: title,
            playCount: "--",
            danmakuCount: "--",
            uploader: "",
            duration: duration,
            progressSeconds: nil,
            publishTimeText: "--",
            bottomRcmdReasonText: nil
        )
    }
}

