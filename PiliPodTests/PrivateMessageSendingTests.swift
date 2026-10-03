import Foundation
import SwiftProtobuf
import Testing
@testable import PiliPod

struct PrivateMessageSendingTests {
    @Test func textAndEmotesSurviveWireEncoding() throws {
        let text = "你好 [doge] 😀 + & = \"引号\"\n第二行"
        let request = try PrivateMessageSending.request(senderID: 123, receiverID: 456,
            text: text, timestamp: 1_700_000_000, deviceID: "test-device")
        let decoded = try Bilibili_Im_Interface_V1_ReqSendMsg(serializedBytes: request.serializedData())
        #expect(decoded.msg.senderUid == 123)
        #expect(decoded.msg.receiverID == 456)
        #expect(decoded.msg.receiverType == .enRecverTypePeer)
        #expect(decoded.msg.msgType == .enMsgTypeText)
        #expect(decoded.msg.newFaceVersion == 1)
        #expect(decoded.msg.timestamp == 1_700_000_000)
        #expect(decoded.devID == "test-device")
        let content = try JSONDecoder().decode([String: String].self, from: Data(decoded.msg.content.utf8))
        #expect(content["content"] == text)
    }

    @Test func cookieFormPreservesPlusAndSpecialCharacters() throws {
        let text = "a+b & c=你好😀\n[d oge]"
        let body = try #require(PrivateMessageSending.formBody(["msg[content]": text]))
        let raw = String(decoding: body, as: UTF8.self)
        #expect(raw.contains("%2B"))
        #expect(!raw.contains("+"))
        var components = URLComponents()
        components.percentEncodedQuery = raw
        #expect(components.queryItems?.first?.value == text)
        #expect(components.queryItems?.first?.name == "msg[content]")
    }

    @Test func messageKeySupportsNumberAndStringWithoutPrecisionLoss() throws {
        for raw in ["{\"msg_key\":18446744073709551614}", "{\"msg_key\":\"18446744073709551614\"}"] {
            let result = try JSONDecoder().decode(PrivateMessageRESTSendData.self, from: Data(raw.utf8))
            #expect(result.msgKey == UInt64.max - 1)
        }
    }
}
