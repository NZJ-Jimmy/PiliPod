import SwiftUI
import PhotosUI
import Combine

@MainActor
final class ConversationViewModel: ObservableObject {
    let session: PrivateMessageSession
    private let service: any ConversationMessageService
    private(set) var messages: [Bilibili_Im_Type_Msg] = []
    @Published private(set) var rows: [MessagePresentation] = []
    @Published var scrollRequest: String?
    @Published var isLoadingHistory = false
    @Published var hasMoreHistory = false
    @Published var historyError: String?
    private var contentCache: [String: (Bilibili_Im_Type_Msg, MessageContent)] = [:]
    private var localIDs: [String: String] = [:]
    private var sentIDs: Set<String> = []
    private var pending: MessagePresentation?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var inputText = ""
    @Published var isSending = false
    @Published var pendingPhotos: [PrivateMessagePhoto] = []
    @Published var uploadedPhotos: [UUID: PrivateMessageImagePayload] = [:]
    @Published var photoSelections: [PhotosPickerItem] = []
    @Published var preparedPhotoSelections: [(item: PhotosPickerItem, photo: PrivateMessagePhoto)] = []
    @Published var isPreparingPhoto = false
    @Published var photoStatus: String?
    @Published var sendError: String?
    @Published var emotePackages: [ReplyEmotePackage] = []
    @Published var selectedPackageID: Int?
    @Published var isLoadingEmotes = false
    @Published var emoteError: String?
    @Published var emotionURLs: [String: String] = [:]
    init(session: PrivateMessageSession, service: (any ConversationMessageService)? = nil) {
        self.session = session
        self.service = service ?? BiliConversationMessageService()
    }
    var currentMID: UInt64 { UInt64(LoginSession.shared.cookies?.DedeUserID ?? "") ?? 0 }
    var pendingPhoto: PrivateMessagePhoto? { pendingPhotos.first }
    var canSend: Bool {
        #if DEBUG
        if ConversationUITestFixture.enabled { return true }
        #endif
        return LoginSession.shared.isLogin
    }

    func rebuildRows() {
        var output = messages.map { message -> MessagePresentation in
            let key = MessagePresentationAdapter.identity(message)
            let content: MessageContent
            if let cached = contentCache[key], cached.0 == message { content = cached.1 }
            else {
                content = MessagePresentationAdapter.content(message)
                contentCache[key] = (message, content)
            }
            return MessagePresentation(id: localIDs[key] ?? key, message: message, content: content,
                isMine: message.senderUid == currentMID)
        }
        if let pending { output.append(pending) }
        if let index = output.lastIndex(where: { $0.isMine }),
           sentIDs.contains(MessagePresentationAdapter.identity(output[index].message)) {
            output[index].delivery = .sent
        }
        rows = MessagePresentationAdapter.layout(output)
    }

    func merge(_ incoming: [Bilibili_Im_Type_Msg]) {
        var combined = Dictionary(messages.map { (MessagePresentationAdapter.identity($0), $0) },
            uniquingKeysWith: { _, latest in latest })
        for message in incoming { combined[MessagePresentationAdapter.identity(message)] = message }
        messages = combined.values.sorted {
            let a = $0.msgSeqno == 0 ? UInt64.max : $0.msgSeqno
            let b = $1.msgSeqno == 0 ? UInt64.max : $1.msgSeqno
            if a != b { return a < b }
            if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
            return MessagePresentationAdapter.identity($0) < MessagePresentationAdapter.identity($1)
        }
        rebuildRows()
    }

    func beginPendingText(_ text: String) {
        // A manual retry reuses the failed bubble rather than creating another local message.
        let retryID = pending?.content.copyText == text ? pending?.id : nil
        var message = Bilibili_Im_Type_Msg()
        message.senderUid = currentMID
        message.timestamp = UInt64(Date().timeIntervalSince1970)
        message.msgType = .enMsgTypeText
        pending = MessagePresentation(id: retryID ?? "local.\(UUID().uuidString)", message: message,
            content: .text(text), isMine: true, delivery: .sending)
        rebuildRows()
        scrollRequest = pending?.id
    }

    func loadOlderMessages() async {
        guard !isLoadingHistory, hasMoreHistory,
              let cursor = messages.map(\.msgSeqno).filter({ $0 > 0 }).min() else { return }
        isLoadingHistory = true
        historyError = nil
        defer { isLoadingHistory = false }
        do {
            #if DEBUG
            if ConversationUITestFixture.enabled {
                try await Task.sleep(for: .milliseconds(ProcessInfo.processInfo.arguments.contains("--uitest-slow-history") ? 10_000 : 250))
                var history = ConversationUITestFixture.messages
                for index in history.indices {
                    history[index].msgKey += 1000
                    history[index].msgSeqno = 0
                    history[index].timestamp = UInt64(index + 1)
                    history[index].content = String(decoding: try JSONEncoder().encode(
                        ["content": "更早消息 \(index + 1)"]), as: UTF8.self)
                }
                messages.insert(contentsOf: history, at: 0)
                rebuildRows()
                hasMoreHistory = false
                return
            }
            #endif
            let fetched = try await service.messages(session: session, before: cursor)
            let older = fetched.filter { $0.msgSeqno > 0 && $0.msgSeqno < cursor }
            merge(older)
            // The endpoint's decoded response currently exposes no explicit has-more flag.
            hasMoreHistory = fetched.count >= 50 && !older.isEmpty
        } catch {
            historyError = error.localizedDescription
            ErrorLogService.record(error, context: "加载更早私信")
        }
    }
    @MainActor
    func loadEmotes() async {
        guard emotePackages.isEmpty, !isLoadingEmotes else { return }
        isLoadingEmotes = true
        emoteError = nil
        defer { isLoadingEmotes = false }
        do {
            emotePackages = try await service.emotes()
            for package in emotePackages {
                for emote in package.emote { emotionURLs[emote.text] = emote.url }
            }
            if emotePackages.isEmpty { emoteError = "暂无 B 站表情，可使用 Emoji" }
        } catch {
            emoteError = "B 站表情加载失败，可使用 Emoji"
            ErrorLogService.record(error, context: "加载私信表情")
        }
    }

    func removePhoto(_ photo: PrivateMessagePhoto) {
        if let selection = preparedPhotoSelections.first(where: { $0.photo.id == photo.id }) {
            photoSelections.removeAll { $0 == selection.item }
        }
        preparedPhotoSelections.removeAll { $0.photo.id == photo.id }
        pendingPhotos.removeAll { $0.id == photo.id }
        uploadedPhotos[photo.id] = nil
    }

    @MainActor
    func preparePhotos() async {
        guard !isSending else { return }
        let selections = photoSelections
        preparedPhotoSelections.removeAll { record in !selections.contains(record.item) }
        pendingPhotos = preparedPhotoSelections.map { $0.photo }
        uploadedPhotos = uploadedPhotos.filter { entry in pendingPhotos.contains { $0.id == entry.key } }
        isPreparingPhoto = true
        defer { if photoSelections == selections { isPreparingPhoto = false } }
        do {
            for item in selections {
                try Task.checkCancellation()
                if preparedPhotoSelections.contains(where: { $0.item == item }) { continue }
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw APIError.businessError(code: -400, message: "无法读取图片，请重新选择")
                }
                try Task.checkCancellation()
                guard photoSelections.contains(item) else { continue }
                preparedPhotoSelections.append((item, try PrivateMessagePhoto.prepare(data)))
                pendingPhotos = selections.compactMap { item in
                    preparedPhotoSelections.first(where: { $0.item == item })?.photo
                }
            }
        } catch is CancellationError {
            // Live selections changed while an iCloud download was in progress.
        } catch {
            guard !Task.isCancelled else { return }
            sendError = error.localizedDescription
        }
    }

    @MainActor
    func sendMessage() async {
        guard !isSending, !isPreparingPhoto, !isLoading, session.sessionType == 1,
              pendingPhoto != nil || !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = inputText
        if pendingPhoto == nil { beginPendingText(text) }
        isSending = true
        defer { isSending = false; photoStatus = nil }
        do {
            let result: PrivateMessageSendResult
            if pendingPhoto != nil {
              while let photo = pendingPhoto {
                if uploadedPhotos[photo.id] == nil {
                    photoStatus = "正在上传图片…"
                    uploadedPhotos[photo.id] = try await service.uploadImage(data: photo.data)
                }
                guard let uploadedPhoto = uploadedPhotos[photo.id] else { throw APIError.requestFailed }
                photoStatus = "正在发送图片…"
                let sent = try await service.sendImage(talkerID: session.talkerID, image: uploadedPhoto)
                appendSentMessage(sent)
                removePhoto(photo)
              }
              await refreshMessagesAfterSending()
              return
            } else {
                #if DEBUG
                if ConversationUITestFixture.enabled {
                    // Exercise sending UI without contacting a real account.
                    try await Task.sleep(for: .milliseconds(350))
                    var message = Bilibili_Im_Type_Msg()
                    message.senderUid = currentMID
                    message.timestamp = UInt64(Date().timeIntervalSince1970)
                    message.msgKey = (messages.map(\.msgKey).max() ?? 0) + 1
                    message.msgType = .enMsgTypeText
                    message.content = String(decoding: try JSONEncoder().encode(["content": text]), as: UTF8.self)
                    if let pending { localIDs[MessagePresentationAdapter.identity(message)] = pending.id }
                    pending = nil
                    sentIDs.insert(MessagePresentationAdapter.identity(message))
                    messages.append(message)
                    
                    if inputText == text { inputText = "" }
                    rebuildRows()
                    scrollRequest = rows.last?.id
                    return
                }
                #endif
                result = try await service.sendText(talkerID: session.talkerID, text: text)
                if inputText == text { inputText = "" }
            }
            appendSentMessage(result)
            await refreshMessagesAfterSending()
        } catch {
            if var failed = pending {
                failed.delivery = .failed
                pending = failed
                if let index = rows.firstIndex(where: { $0.id == failed.id }) {
                    rows[index].delivery = .failed
                }
            }
            sendError = "\(error.localizedDescription)\n内容已保留，可稍后重试。若网络超时，请先确认对方是否已收到。"
            ErrorLogService.record(error, context: "发送私信")
        }
    }

    func appendSentMessage(_ result: PrivateMessageSendResult) {
            let key = MessagePresentationAdapter.identity(result.message)
            if result.message.msgType == .enMsgTypeText {
                if let pending { localIDs[key] = pending.id }
                pending = nil
            }
            sentIDs.insert(key)
            
            for emotion in result.emotions { emotionURLs[emotion.text] = emotion.url }
            if !messages.contains(where: { $0.msgKey == result.message.msgKey }) {
                messages.append(result.message)
            }
            errorMessage = nil
            rebuildRows()
            scrollRequest = rows.last?.id
    }

    func refreshMessagesAfterSending() async {
        do {
            let fetched = try await service.messages(session: session, before: 0)
                
            merge(fetched)
        } catch {
            // Sending already succeeded; a failed history refresh must not offer a duplicate resend.
            ErrorLogService.record(error, context: "发送后同步私信")
        }
    }

    func loadMessages() async {
        #if DEBUG
        if ConversationUITestFixture.enabled {
            messages = ConversationUITestFixture.messages
            rebuildRows()
            isLoading = false
            hasMoreHistory = true
            return
        }
        #endif
        guard LoginSession.shared.isLogin else {
            isLoading = false
            errorMessage = "请先登录"
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await service.messages(session: session, before: 0)
            merge(fetched)
            hasMoreHistory = fetched.count >= 50

        } catch {
            errorMessage = error.localizedDescription
            ErrorLogService.record(error, context: "加载私信详情")
        }
        isLoading = false
    }
}
