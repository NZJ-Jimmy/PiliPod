import SwiftUI

struct VideoCommentPreviewView: View {
    let aid: Int
    let commentCount: Int
    let onOpenUserSpace: (Int) -> Void

    private struct Preview: Identifiable {
        let id: Int64
        let username: String
        let content: String
        let likes: Int64
    }

    @State private var previews: [Preview] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var showsComments = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showsComments = true
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
                Button("暂无评论，来说点什么吧") { showsComments = true }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(previews) { preview in
                            Button {
                                showsComments = true
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(preview.username)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text(preview.content)
                                        .font(.subheadline)
                                        .lineLimit(4)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    Label("\(preview.likes)", systemImage: "hand.thumbsup")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .foregroundStyle(.primary)
                                .padding(16)
                                .frame(width: 280, height: 180, alignment: .topLeading)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("查看全部评论")
                        }
                    }
                }
            }
        }
        .task(id: aid) { await loadPreviews() }
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
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    @MainActor
    private func loadPreviews() async {
        guard aid > 0 else { return }
        let requestedAid = aid
        isLoading = true
        errorText = nil
        previews = []
        defer { isLoading = false }
        do {
            let response = try await BiliAPI.shared.fetchVideoCommentMainList(oid: Int64(requestedAid), type: 1)
            try Task.checkCancellation()
            previews = response.replies.prefix(3).map {
                Preview(id: $0.id, username: $0.member.name.isEmpty ? "匿名用户" : $0.member.name,
                        content: $0.content.message, likes: $0.like)
            }
        } catch is CancellationError {
            return
        } catch {
            errorText = error.localizedDescription
            ErrorLogService.record(error, context: "加载评论预览")
        }
    }
}
