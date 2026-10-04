import Foundation

enum MessageGroupPosition: Equatable {
    case single, first, middle, last
    var hasTail: Bool { self == .single || self == .last }
    var startsGroup: Bool { self == .single || self == .first }
}

enum MessageDeliveryState: String {
    case sending = "正在发送…"
    case sent = "已发送"
    case failed = "发送失败"
}

enum MessageContent {
    case text(String)
    case image(PrivateMessageImagePayload)
    case card(MessageCardPayload)
    case notice(String)
    case unsupported(String)

    var isSystem: Bool { if case .notice = self { return true }; return false }
    var copyText: String? {
        switch self {
        case .text(let text): text
        case .card(let card): card.title
        default: nil
        }
    }
}

struct MessagePresentation: Identifiable {
    let id: String
    let message: Bilibili_Im_Type_Msg
    let content: MessageContent
    let isMine: Bool
    var position: MessageGroupPosition = .single
    var timestamp: Date?
    var delivery: MessageDeliveryState?
}

/// Parsing is cached by the conversation model. Grouping uses only adjacent metadata.
enum MessagePresentationAdapter {
    static let groupingInterval: UInt64 = 5 * 60
    static let timestampInterval: UInt64 = 15 * 60

    static func identity(_ message: Bilibili_Im_Type_Msg) -> String {
        if message.msgKey > 0 { return "message.\(message.msgKey)" }
        return "sequence.\(message.msgSeqno).\(message.senderUid).\(message.timestamp).\(message.content)"
    }

    static func content(_ message: Bilibili_Im_Type_Msg) -> MessageContent {
        let type = message.msgType.rawValue
        if type == 5 || type == 8 {
            return .notice("消息已撤回")
        }
        if message.sysCancel || message.msgStatus == 2 { return .notice("此消息已不可用") }
        if type == 2, let image = try? JSONDecoder().decode(PrivateMessageImagePayload.self, from: Data(message.content.utf8)) {
            return .image(image)
        }
        if let card = MessageCardPayload(message: message) { return .card(card) }
        if type == 1 || type == 18 { return .text(MessagePayload.text(from: message)) }
        if type >= 101 { return .notice("系统消息") }
        let label = type == 3 ? "语音" : type == 2 || type == 6 ? "图片" : "此类型消息"
        return .unsupported("暂不支持查看\(label)")
    }

    static func layout(_ input: [MessagePresentation], calendar: Calendar = .current) -> [MessagePresentation] {
        var rows = input
        for index in rows.indices {
            let message = rows[index].message
            let previous = index > 0 ? rows[index - 1] : nil
            if message.timestamp > 0 {
                let date = Date(timeIntervalSince1970: TimeInterval(message.timestamp))
                if previous == nil || previous!.message.timestamp == 0 ||
                    !calendar.isDate(date, inSameDayAs: Date(timeIntervalSince1970: TimeInterval(previous!.message.timestamp))) ||
                    (message.timestamp >= previous!.message.timestamp && message.timestamp - previous!.message.timestamp > timestampInterval) {
                    rows[index].timestamp = date
                } else { rows[index].timestamp = nil }
            } else { rows[index].timestamp = nil }
        }
        for index in rows.indices {
            let before = index > 0 && groups(rows[index - 1], rows[index], calendar: calendar)
            let after = index + 1 < rows.count && groups(rows[index], rows[index + 1], calendar: calendar)
            rows[index].position = before ? (after ? .middle : .last) : (after ? .first : .single)
        }
        return rows
    }

    private static func groups(_ first: MessagePresentation, _ second: MessagePresentation, calendar: Calendar) -> Bool {
        let a = first.message, b = second.message
        guard a.senderUid == b.senderUid, a.timestamp > 0, b.timestamp >= a.timestamp,
              b.timestamp - a.timestamp <= groupingInterval, second.timestamp == nil,
              !first.content.isSystem, !second.content.isSystem else { return false }
        return calendar.isDate(Date(timeIntervalSince1970: TimeInterval(a.timestamp)),
            inSameDayAs: Date(timeIntervalSince1970: TimeInterval(b.timestamp)))
    }
}
