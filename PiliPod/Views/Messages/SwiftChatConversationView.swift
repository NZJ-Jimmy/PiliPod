import SwiftUI
import SwiftChat

struct MessageConversationView: View {
    let session: PrivateMessageSession
    @StateObject private var model: ConversationViewModel
    @StateObject private var keyboard = ConversationKeyboard()
    @State private var pendingMedia: [MessageMedia] = []
    @State private var preparedMedia: [MessageMedia: PrivateMessagePhoto] = [:]
    @State private var isProcessingSend = false
    @State private var isFocused = false
    @State private var showEmotes = false
    @State private var inputPanel: ConversationInputPanel?
    @State private var isPanelExpanded = false
    @State private var panelDismissal: CGFloat = 0
    @FocusState private var emoteFocus: Bool
    @State private var selectedVideo: VideoItem?
    @State private var selectedUserMID: Int?
    @Namespace private var videoHeroNamespace

    init(session: PrivateMessageSession) {
        self.session = session
        _model = StateObject(wrappedValue: ConversationViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            Chat(model.rows) { row in sdkMessage(row) }
                .chatInputHidden(true)
                .chatBubbleStyle(Color("BiliPink"))
                .chatAutoscrollBehavior(.whenAtBottom)
                .chatHeader {
                    ChatHeader(title: session.name, avatarURL: MessagePayload.url(from: session.avatarURL)) {
                        if session.sessionType == 1, session.talkerID <= UInt64(Int.max) {
                            selectedUserMID = Int(session.talkerID)
                        }
                    }
                }
                .chatEmptyView {
                    if model.isLoading { ProgressView("加载消息中…") }
                    else if let error = model.errorMessage {
                        VStack { Text(error); Button("重试") { Task { await model.loadMessages() } } }
                    } else { ContentUnavailableView("暂无消息", systemImage: "bubble.left.and.bubble.right") }
                }
                .chatLoadsOlderMessages {
                    await model.loadOlderMessages()
                    return model.hasMoreHistory
                }
                .chatMessageContextMenu { (id: String) in
                    if let text = model.rows.first(where: { $0.id == id })?.content.copyText {
                        [ChatContextMenuItem("复制", systemImage: "doc.on.doc") { UIPasteboard.general.string = text }]
                    } else { [] }
                }
            if session.sessionType == 1 {
                if isProcessingSend { ProgressView(model.photoStatus ?? "正在发送…").font(.caption) }
                HStack(alignment: .bottom, spacing: 0) {
                    // Bind the SDK composer so failures retain text and selected media.
                    ChatInputBarWithAttachments(text: $model.inputText, pendingMedia: $pendingMedia,
                        placeholder: "消息", capabilities: [.photoLibrary],
                        onSend: { Task { await send() } }, isFocused: $isFocused)
                    Button { isFocused = false; showEmotes = true } label: {
                        Image(systemName: "face.smiling").font(.title3).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain).accessibilityLabel("选择表情").padding(.bottom, 8)
                }
                .chatInputControlTint(Color("BiliPink"))
                .chatDictationDisabled(true)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor).toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await model.loadMessages()
            #if DEBUG
            if ConversationUITestFixture.enabled { return }
            #endif
            await model.loadEmotes()
        }
        .sheet(isPresented: $showEmotes, onDismiss: { isFocused = true }) {
            NavigationStack {
              MessageComposer(model: model, keyboard: keyboard, inputPanel: $inputPanel,
                isPanelExpanded: $isPanelExpanded, panelDismissal: $panelDismissal, focus: $emoteFocus)
                .emotePanel
                .navigationTitle("表情").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showEmotes = false }.accessibilityLabel("完成表情选择")
                } }
            }
                .presentationDetents([.height(keyboard.lastHeight), .large])
                .presentationDragIndicator(.visible)
                .task {
                    #if DEBUG
                    if ConversationUITestFixture.enabled { return }
                    #endif
                    await model.loadEmotes()
                }
        }
        .navigationDestination(item: $selectedUserMID) { UserSpaceView(mid: $0) }
        .navigationDestination(item: $selectedVideo) { video in
            VideoDetailPage(video: video, namespace: videoHeroNamespace, onBack: { selectedVideo = nil })
        }
        .alert("发送失败", isPresented: Binding(get: { model.sendError != nil },
            set: { if !$0 { model.sendError = nil } })) {
            Button("好的", role: .cancel) { model.sendError = nil }
        } message: { Text(model.sendError ?? "") }
    }

    private func sdkMessage(_ row: MessagePresentation) -> Message {
        let role: ChatRole = row.content.isSystem ? .system : row.isMine ? .me :
            .user(id: String(row.message.senderUid), displayName: session.name)
        let date = Date(timeIntervalSince1970: TimeInterval(row.message.timestamp))
        var message: Message
        switch row.content {
        case .text(let text):
            if model.emotionURLs.keys.contains(where: { text.contains($0) }) {
                message = Message("", role: role, timestamp: date).messageAttachment {
                    PrivateMessageText(text: text, emotionURLs: model.emotionURLs)
                        .foregroundStyle(row.isMine ? .white : .primary).padding(10)
                }
            } else { message = Message(text, role: role, timestamp: date) }
        case .image(let payload):
            message = Message("", role: role, timestamp: date)
                .messageMedia(MessagePayload.url(from: payload.url).map {
                    .image(url: $0, width: payload.width, height: payload.height)
                })
        case .card(let card):
            message = Message("", role: role, timestamp: date).messageAttachment {
                BiliMessageCard(card: card, heroNamespace: videoHeroNamespace,
                    onVideoTap: { selectedVideo = card.videoItem }, isMine: row.isMine,
                    isEmbedded: card.isUserVideoShare)
            }
        case .notice(let text), .unsupported(let text): message = Message(text, role: role, timestamp: date)
        }
        message.id = AnyHashable(row.id)
        switch row.delivery {
        case .sending: message = message.messageStatus(.sending)
        case .sent: message = message.messageStatus(.sent)
        case .failed: message = message.messageStatus(.failed)
        case nil: break
        }
        return message.contentVersion(row.message.content + String(describing: row.delivery))
    }

    @MainActor private func send() async {
        guard !isProcessingSend, !model.isLoading, model.canSend else { return }
        isProcessingSend = true
        defer { isProcessingSend = false }
        model.sendError = nil
        let selection = pendingMedia
        let text = model.inputText
        do {
            for media in selection where preparedMedia[media] == nil {
                guard case .image(let url, _, _, _) = media else {
                    throw APIError.businessError(code: -400, message: "私信仅支持图片附件")
                }
                preparedMedia[media] = try PrivateMessagePhoto.prepare(await SwiftChatMediaData.read(url))
            }
            model.pendingPhotos = selection.compactMap { preparedMedia[$0] }
            if !model.pendingPhotos.isEmpty {
                await model.sendMessage()
                let remaining = Set(model.pendingPhotos.map(\.id))
                let completed = selection.filter { media in
                    preparedMedia[media].map { !remaining.contains($0.id) } ?? false
                }
                pendingMedia.removeAll { completed.contains($0) }
                for media in completed { preparedMedia[media] = nil }
                if model.sendError != nil { return }
            }
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await model.sendMessage(textOverride: text)
            }
        } catch { model.sendError = "\(error.localizedDescription)\n内容已保留，可稍后重试。" }
    }
}
