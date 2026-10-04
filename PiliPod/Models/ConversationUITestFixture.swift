#if DEBUG
import Foundation
import SwiftUI

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
        let history = (1...20).map { "历史消息 \($0)" } +
            ["这是一条收到的消息", "文字和表情测试 😀", "多行输入和面板布局测试"]
        return history.enumerated().map { index, text in
            var message = Bilibili_Im_Type_Msg()
            if ProcessInfo.processInfo.arguments.contains("--uitest-groups"), index >= 15 {
                message.senderUid = index < 19 ? 0 : 123
            } else {
                message.senderUid = index.isMultiple(of: 2) ? 123 : 0
            }
            message.msgKey = UInt64(index + 1)
            message.msgSeqno = UInt64(index + 1)
            message.timestamp = 1_790_000_000 + UInt64(index * 60)
            message.msgType = .enMsgTypeText
            message.content = String(decoding: try! JSONEncoder().encode(["content": text]), as: UTF8.self)
            return message
        }
    }
}

struct ConversationUITestHost: View {
    @State private var path = [ConversationUITestFixture.session]
    var body: some View {
        NavigationStack(path: $path) {
            Text("私信测试").navigationTitle("消息")
                .navigationDestination(for: PrivateMessageSession.self) { session in
                    MessageConversationView(session: session)
                }
        }
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--uitest-dark") ? .dark : .light)
    }
}

struct ConversationUITestAppearance: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(ConversationUITestFixture.enabled &&
                ProcessInfo.processInfo.arguments.contains("--uitest-dark") ? .dark : nil)
            .environment(\.dynamicTypeSize, ConversationUITestFixture.enabled &&
                ProcessInfo.processInfo.arguments.contains("--uitest-large-text") ? .accessibility2 : dynamicTypeSize)
    }
}
#endif
