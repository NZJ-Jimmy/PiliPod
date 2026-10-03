import Foundation
import SwiftProtobuf
import UIKit
import Testing
@testable import PiliPod

struct PrivateMessageSendingTests {
    @Test func imageMessageUsesPictureTypeAndServerMetadata() throws {
        let image = PrivateMessageImagePayload(url: "https://i0.hdslb.com/test.jpg", height: 480,
            width: 640, imageType: "jpg", original: 1, size: 12345)
        let request = try PrivateMessageSending.imageRequest(senderID: 123, receiverID: 456,
            image: image, timestamp: 1_700_000_000, deviceID: "test-device")
        let decoded = try Bilibili_Im_Interface_V1_ReqSendMsg(serializedBytes: request.serializedData())
        #expect(decoded.msg.msgType == .enMsgTypePic)
        #expect(decoded.msg.receiverID == 456)
        let payload = try JSONDecoder().decode(PrivateMessageImagePayload.self, from: Data(decoded.msg.content.utf8))
        #expect(payload.url == image.url)
        #expect(payload.width == 640)
        #expect(payload.height == 480)
        #expect(payload.imageType == "jpg")
        #expect(payload.size == 12345)
        #expect(payload.original == 1)
    }

    @Test func olderImageMessagesCanOmitOptionalMetadata() throws {
        let payload = try JSONDecoder().decode(PrivateMessageImagePayload.self,
            from: Data("{\"url\":\"https://i0.hdslb.com/test.jpg\",\"width\":640,\"height\":480}".utf8))
        #expect(payload.width == 640)
        #expect(payload.imageType == "jpg")
    }

    @MainActor @Test func selectedPhotoIsResizedAndEncodedAsJPEG() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1500), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
        }
        let photo = try PrivateMessagePhoto.prepare(try #require(source.pngData()))
        #expect(photo.image.size.width == 2048)
        #expect(photo.image.size.height == 1024)
        #expect(Array(photo.data.prefix(2)) == [0xFF, 0xD8])
    }

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
