import Foundation

/// A conversation-specific boundary for testing state transitions; the Bilibili API remains unchanged.
@MainActor
protocol ConversationMessageService {
    func messages(session: PrivateMessageSession, before sequence: UInt64) async throws -> [Bilibili_Im_Type_Msg]
    func sendText(talkerID: UInt64, text: String) async throws -> PrivateMessageSendResult
    func sendImage(talkerID: UInt64, image: PrivateMessageImagePayload) async throws -> PrivateMessageSendResult
    func uploadImage(data: Data) async throws -> PrivateMessageImagePayload
    func emotes() async throws -> [ReplyEmotePackage]
}

@MainActor
struct BiliConversationMessageService: ConversationMessageService {
    func messages(session: PrivateMessageSession, before sequence: UInt64) async throws -> [Bilibili_Im_Type_Msg] {
        try await BiliAPI.shared.fetchPrivateMessageMessages(talkerID: session.talkerID,
            sessionType: session.sessionType, endSeqno: sequence)
    }
    func sendText(talkerID: UInt64, text: String) async throws -> PrivateMessageSendResult {
        try await BiliAPI.shared.sendPrivateMessage(talkerID: talkerID, text: text)
    }
    func sendImage(talkerID: UInt64, image: PrivateMessageImagePayload) async throws -> PrivateMessageSendResult {
        try await BiliAPI.shared.sendPrivateMessageImage(talkerID: talkerID, image: image)
    }
    func uploadImage(data: Data) async throws -> PrivateMessageImagePayload {
        try await BiliAPI.shared.uploadPrivateMessageImage(data: data)
    }
    func emotes() async throws -> [ReplyEmotePackage] {
        try await BiliAPI.shared.fetchUserReplyEmotePackages()
    }
}
