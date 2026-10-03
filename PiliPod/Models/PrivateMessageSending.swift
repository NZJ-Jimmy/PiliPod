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
