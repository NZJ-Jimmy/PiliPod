import SwiftUI
import SwiftChat

@main
struct SwiftChatDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoConversationView()
        }
    }
}

struct DemoMessage: Identifiable {
    let id = UUID()
    var text: String
    var role: ChatRole
    var sentAt: Date
    var status: ChatDeliveryStatus?
}

struct DemoConversationView: View {
    @State private var messages: [DemoMessage] = [
        DemoMessage(
            text: "这是 Swift Chat 的 Demo。UI 由 unionst/swift-chat 渲染。",
            role: .user(id: "alice", displayName: "Alice"),
            sentAt: .now.addingTimeInterval(-300),
            status: nil
        ),
        DemoMessage(
            text: "看起来确实很像 iMessage。",
            role: .me,
            sentAt: .now.addingTimeInterval(-240),
            status: .read
        ),
        DemoMessage(
            text: "后面可以把 PiliPod 私信接口的数据直接映射到这里。",
            role: .user(id: "alice", displayName: "Alice"),
            sentAt: .now.addingTimeInterval(-180),
            status: nil
        ),
        DemoMessage(
            text: "发送一条消息试试看 👇",
            role: .me,
            sentAt: .now.addingTimeInterval(-120),
            status: .delivered
        )
    ]

    @State private var typing: [ChatRole] = []

    var body: some View {
        NavigationStack {
            Chat(messages) { message in
                Message(
                    message.text,
                    role: message.role,
                    timestamp: message.sentAt
                )
                .messageStatus(message.status)
            }
            .chatTypingIndicators(typing)
            .chatInputPlaceholder("iMessage")
            .chatInputCapabilities([.photoLibrary, .files])
            .onChatSend { text, media in
                let body = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !body.isEmpty || !media.isEmpty else { return }

                let sentID: UUID? = await MainActor.run {
                    messages.append(
                        DemoMessage(
                            text: body.isEmpty ? "[附件]" : body,
                            role: .me,
                            sentAt: .now,
                            status: .sending
                        )
                    )
                    return messages.last?.id
                }

                try? await Task.sleep(for: .milliseconds(450))

                await MainActor.run {
                    if let sentID,
                       let index = messages.firstIndex(where: { $0.id == sentID }) {
                        messages[index].status = .delivered
                    }
                    typing = [.user(id: "alice", displayName: "Alice")]
                }

                try? await Task.sleep(for: .milliseconds(850))

                await MainActor.run {
                    typing = []
                    messages.append(
                        DemoMessage(
                            text: "收到。这个 Demo 目前使用本地模拟回复。",
                            role: .user(id: "alice", displayName: "Alice"),
                            sentAt: .now,
                            status: nil
                        )
                    )

                    if let sentID,
                       let index = messages.firstIndex(where: { $0.id == sentID }) {
                        messages[index].status = .read
                    }
                }
            }
            .navigationTitle("Alice")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
