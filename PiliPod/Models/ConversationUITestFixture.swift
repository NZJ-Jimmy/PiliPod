#if DEBUG
import Foundation

enum ConversationUITestFixture {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--uitest-conversation") }
    static var session: PrivateMessageSession {
        var session = Bilibili_Im_Type_SessionInfo()
        session.talkerID = 123
        session.sessionType = 1
        session.accountInfo.name = "测试联系人"
        return PrivateMessageSession(session: session)
    }
    static var messages: [Bilibili_Im_Type_Msg] {
        ["这是一条收到的消息", "文字和表情测试 😀", "多行输入和面板布局测试"].enumerated().map { index, text in
            var message = Bilibili_Im_Type_Msg()
            message.senderUid = index == 0 ? 123 : 0
            message.msgKey = UInt64(index + 1)
            message.msgSeqno = UInt64(index + 1)
            message.msgType = .enMsgTypeText
            message.content = String(decoding: try! JSONEncoder().encode(["content": text]), as: UTF8.self)
            return message
        }
    }
}
#endif
