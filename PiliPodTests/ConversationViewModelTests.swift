import Foundation
import Testing
@testable import PiliPod

@MainActor
private final class RecordingConversationService: ConversationMessageService {
    enum Failure: Error { case rejected }
    var rejectText = false
    var rejectRefresh = false
    var rejectImageNumber: Int?
    var sentTexts: [String] = []
    var imageAttempts = 0
    var uploads = 0
    var onText: (() -> Void)?

    func messages(session: PrivateMessageSession, before sequence: UInt64) async throws -> [Bilibili_Im_Type_Msg] {
        if rejectRefresh { throw Failure.rejected }
        return []
    }
    func sendText(talkerID: UInt64, text: String) async throws -> PrivateMessageSendResult {
        sentTexts.append(text)
        onText?()
        await Task.yield()
        if rejectText { throw Failure.rejected }
        var message = Bilibili_Im_Type_Msg()
        message.msgKey = 100
        message.senderUid = 0
        message.timestamp = UInt64(Date().timeIntervalSince1970)
        message.msgType = .enMsgTypeText
        message.content = String(decoding: try JSONEncoder().encode(["content": text]), as: UTF8.self)
        return PrivateMessageSendResult(message: message, emotions: [])
    }
    func sendImage(talkerID: UInt64, image: PrivateMessageImagePayload) async throws -> PrivateMessageSendResult {
        imageAttempts += 1
        if imageAttempts == rejectImageNumber { throw Failure.rejected }
        var message = Bilibili_Im_Type_Msg()
        message.msgKey = UInt64(imageAttempts)
        message.msgType = .enMsgTypePic
        message.content = String(decoding: try JSONEncoder().encode(image), as: UTF8.self)
        return PrivateMessageSendResult(message: message, emotions: [])
    }
    func uploadImage(data: Data) async throws -> PrivateMessageImagePayload {
        uploads += 1
        return PrivateMessageImagePayload(url: "https://i0.hdslb.com/\(uploads).jpg", height: 480,
            width: 640, imageType: "jpg", original: 1, size: Double(data.count))
    }
    func emotes() async throws -> [ReplyEmotePackage] { [] }
}

@MainActor
struct ConversationViewModelTests {
    private func model(_ service: RecordingConversationService) -> ConversationViewModel {
        var session = Bilibili_Im_Type_SessionInfo()
        session.sessionType = 1
        session.talkerID = 123
        let model = ConversationViewModel(session: PrivateMessageSession(session: session), service: service)
        model.isLoading = false
        return model
    }

    @Test func failedSendPreservesDraftAndManualRetryReusesBubble() async {
        let service = RecordingConversationService()
        service.rejectText = true
        let model = model(service)
        model.inputText = "draft 😀"
        await model.sendMessage()
        let failedID = model.rows.first?.id
        #expect(model.inputText == "draft 😀")
        #expect(model.rows.first?.delivery == .failed)
        #expect(model.sendError != nil)
        #expect(!model.isSending)
        service.rejectText = false
        model.sendError = nil
        await model.sendMessage()
        #expect(model.rows.count == 1)
        #expect(model.rows.first?.id == failedID)
        #expect(model.rows.first?.delivery == .sent)
        #expect(model.inputText.isEmpty)
        #expect(service.sentTexts == ["draft 😀", "draft 😀"])
    }

    @Test func typingWhileSendingDoesNotLoseNewDraft() async {
        let service = RecordingConversationService()
        let model = model(service)
        model.inputText = "first"
        service.onText = { model.inputText = "next draft" }
        await model.sendMessage()
        #expect(model.inputText == "next draft")
        #expect(model.rows.count == 1)
        #expect(model.rows.first?.content.copyText == "first")
    }

    @Test func failedRefreshAfterAcknowledgementDoesNotOfferResend() async {
        let service = RecordingConversationService()
        service.rejectRefresh = true
        let model = model(service)
        model.inputText = "accepted"
        await model.sendMessage()
        #expect(model.inputText.isEmpty)
        #expect(model.sendError == nil)
        #expect(model.rows.first?.delivery == .sent)
        #expect(service.sentTexts.count == 1)
    }

    @Test func partialImageFailureRetainsOnlyUnsentPhotosAndReusesUpload() async {
        let service = RecordingConversationService()
        service.rejectImageNumber = 2
        let model = model(service)
        let first = PrivateMessagePhoto(data: Data([1]))
        let second = PrivateMessagePhoto(data: Data([2]))
        model.pendingPhotos = [first, second]
        model.inputText = "retain text while sending photos"
        await model.sendMessage()
        #expect(model.pendingPhotos.map(\.id) == [second.id])
        #expect(service.uploads == 2)
        #expect(model.uploadedPhotos[second.id] != nil)
        #expect(model.rows.count == 1)
        #expect(model.inputText == "retain text while sending photos")
        service.rejectImageNumber = nil
        model.sendError = nil
        await model.sendMessage()
        #expect(model.pendingPhotos.isEmpty)
        #expect(service.uploads == 2)
        #expect(model.rows.count == 2)
        #expect(model.inputText == "retain text while sending photos")
    }
}
