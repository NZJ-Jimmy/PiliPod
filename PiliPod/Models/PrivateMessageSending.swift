import Foundation

enum PrivateMessageSending {
    static func formBody(_ parameters: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = parameters.sorted { $0.key < $1.key }.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        return components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
    }

    static func request(senderID: UInt64, receiverID: UInt64, text: String,
                        timestamp: UInt64, deviceID: String) throws -> Bilibili_Im_Interface_V1_ReqSendMsg {
        var message = Bilibili_Im_Type_Msg()
        message.senderUid = senderID
        message.receiverID = receiverID
        message.receiverType = .enRecverTypePeer
        message.msgType = .enMsgTypeText
        message.content = String(decoding: try JSONEncoder().encode(["content": text]), as: UTF8.self)
        message.timestamp = timestamp
        message.newFaceVersion = 1
        var request = Bilibili_Im_Interface_V1_ReqSendMsg()
        request.msg = message
        request.devID = deviceID
        return request
    }

    static func imageRequest(senderID: UInt64, receiverID: UInt64, image: PrivateMessageImagePayload,
                             timestamp: UInt64, deviceID: String) throws -> Bilibili_Im_Interface_V1_ReqSendMsg {
        var request = try self.request(senderID: senderID, receiverID: receiverID, text: "",
                                       timestamp: timestamp, deviceID: deviceID)
        request.msg.msgType = .enMsgTypePic
        request.msg.content = String(decoding: try JSONEncoder().encode(image), as: UTF8.self)
        return request
    }
}

struct PrivateMessageImagePayload: Codable {
    let url: String
    let height: Int
    let width: Int
    let imageType: String
    let original: Int
    let size: Double
}

extension PrivateMessageImagePayload {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        url = try values.decode(String.self, forKey: .url)
        height = try values.decodeIfPresent(Int.self, forKey: .height) ?? 240
        width = try values.decodeIfPresent(Int.self, forKey: .width) ?? 240
        imageType = try values.decodeIfPresent(String.self, forKey: .imageType) ?? "jpg"
        original = try values.decodeIfPresent(Int.self, forKey: .original) ?? 1
        size = try values.decodeIfPresent(Double.self, forKey: .size) ?? 0
    }
}

struct PrivateMessageSendResult {
    let message: Bilibili_Im_Type_Msg
    let emotions: [Bilibili_Im_Interface_V1_EmotionInfo]
}

struct PrivateMessageRESTSendData: Decodable {
    let msgKey: UInt64
    enum CodingKeys: String, CodingKey { case msgKey = "msg_key" }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let number = try? values.decode(UInt64.self, forKey: .msgKey) {
            msgKey = number
        } else {
            let raw = try values.decode(String.self, forKey: .msgKey)
            guard let number = UInt64(raw) else {
                throw DecodingError.dataCorruptedError(forKey: .msgKey, in: values, debugDescription: "Invalid message key")
            }
            msgKey = number
        }
    }
}
