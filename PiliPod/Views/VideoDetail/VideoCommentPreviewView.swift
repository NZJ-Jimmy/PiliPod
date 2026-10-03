import SwiftUI

struct VideoCommentPreviewView: View {
    let aid: Int
    let commentCount: Int
    let commentSheetHeight: CGFloat
    let onOpenUserSpace: (Int) -> Void

    private struct Preview: Identifiable {
        let id: Int64
        let username: String
        let content: String
        let likes: Int64
    }

    @State private var settings = AudioVideoSettingsStore.load()
    @ScaledMetric(relativeTo: .subheadline) private var bodyLineHeight: CGFloat = 20
    @State private var previews: [Preview] = []
    @State private var requestID = UUID()
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var showsComments = false
    @State private var selectedCommentDetent: PresentationDetent = .large

    private var videoVisibleDetent: PresentationDetent { .height(commentSheetHeight) }

    private func openComments() {
        selectedCommentDetent = videoVisibleDetent
        showsComments = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                openComments()
            } label: {
                HStack {
                    Text("评论 (\(commentCount))")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("查看全部")
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .tint(Color("BiliPink"))

            Picker("评论排序", selection: $settings.commentSortOrder) {
                ForEach(VideoCommentSortOrder.allCases, id: \.self) { order in
                    Text(order.title).tag(order)
                }
            }
            .pickerStyle(.segmented)

            if isLoading {
                ProgressView("评论加载中…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if errorText != nil {
                Button("评论预览加载失败，点击重试") {
                    Task { await loadPreviews() }
                }
                .font(.footnote)
            } else if previews.isEmpty {
                Button("暂无评论，来说点什么吧") { openComments() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(previews) { preview in
                            Button {
                                openComments()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(preview.username)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text(preview.content)
                                        .font(.subheadline)
                                        .lineLimit(settings.commentPreviewLineCount)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(height: bodyLineHeight * CGFloat(settings.commentPreviewLineCount), alignment: .topLeading)
                                    Label("\(preview.likes)", systemImage: "hand.thumbsup")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .foregroundStyle(.primary)
                                .padding(16)
                                .frame(width: 280, alignment: .topLeading)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("查看全部评论")
                        }
                    }
                }
            }
        }
        .task(id: "\(aid)-\(settings.commentSortOrder.rawValue)") { await loadPreviews() }
        .onReceive(NotificationCenter.default.publisher(for: .audioVideoSettingsDidChange)) { notification in
            if let updated = notification.object as? AudioVideoSettings { settings = updated }
        }
        .onChange(of: settings.commentSortOrder) { _, order in
            var updated = AudioVideoSettingsStore.load()
            guard updated.commentSortOrder != order else { return }
            updated.commentSortOrder = order
            AudioVideoSettingsStore.save(updated)
        }
        .onChange(of: commentSheetHeight) { _, _ in
            if selectedCommentDetent != .large { selectedCommentDetent = videoVisibleDetent }
        }
        .sheet(isPresented: $showsComments, onDismiss: {
            Task { await loadPreviews() }
        }) {
            NavigationStack {
                VideoCommentsTabView(aid: aid, onOpenUserSpace: { mid in
                    showsComments = false
                    onOpenUserSpace(mid)
                })
                .navigationTitle("评论")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showsComments = false }
                    }
                }
            }
            .presentationDetents([videoVisibleDetent, .large], selection: $selectedCommentDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: videoVisibleDetent))
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
        }
    }

    @MainActor
    private func loadPreviews() async {
        guard aid > 0 else { return }
        let currentRequestID = UUID()
        requestID = currentRequestID
        let requestedAid = aid
        let requestedOrder = settings.commentSortOrder
        isLoading = true
        errorText = nil
        previews = []
        defer { if requestID == currentRequestID { isLoading = false } }
        do {
            let response = try await BiliAPI.shared.fetchVideoCommentMainList(oid: Int64(requestedAid), type: 1, mode: requestedOrder.apiMode)
            try Task.checkCancellation()
            guard requestID == currentRequestID, settings.commentSortOrder == requestedOrder else { return }
            previews = response.replies.prefix(3).map {
                Preview(id: $0.id, username: $0.member.name.isEmpty ? "匿名用户" : $0.member.name,
                        content: $0.content.message, likes: $0.like)
            }
        } catch is CancellationError {
            return
        } catch {
            guard requestID == currentRequestID else { return }
            errorText = error.localizedDescription
            ErrorLogService.record(error, context: "加载评论预览")
        }
    }
}
