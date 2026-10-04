import SwiftUI

/// A single horizontal preview; its lifetime follows the expanded section.
struct MyPagePreview: View {
    let section: MyPageSection
    let openVideo: (VideoItem) -> Void
    let openFolder: (LibraryFolder) -> Void
    @ObservedObject private var session = LoginSession.shared
    @ObservedObject private var cache = OfflineCacheManager.shared
    @State private var videos: [VideoItem] = []
    @State private var folders: [LibraryFolder] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var retry = 0
    @State private var generation = 0

    private var offlineItems: [OfflineCacheItem] {
        Array(cache.sortedItems.filter { $0.status == .completed }.prefix(6))
    }

    var body: some View {
        Group {
            if section == .offline {
                if offlineItems.isEmpty {
                    message("暂无已完成的离线视频")
                } else {
                    carousel {
                        ForEach(offlineItems) { item in
                            let video = VideoItem(
                                bvid: item.bvid, cid: item.cid, cover: item.cover, title: item.title,
                                playCount: "--", danmakuCount: "--", uploader: item.uploader,
                                duration: item.duration, progressSeconds: nil,
                                publishTimeText: "", bottomRcmdReasonText: nil
                            )
                            previewCard(cover: item.cover, title: item.title, subtitle: "离线 · \(video.durationFormatted)") {
                                openVideo(video)
                            }
                        }
                    }
                }
            } else if !session.isLogin {
                message("登录后查看此内容")
            } else if isLoading && videos.isEmpty && folders.isEmpty {
                ProgressView("加载中…")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage).font(.caption).foregroundStyle(.secondary)
                    Button("重试") { retry += 1 }
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding(.horizontal, 18)
            } else if videos.isEmpty && folders.isEmpty {
                message("暂无内容")
            } else {
                carousel {
                    ForEach(Array(videos.enumerated()), id: \.offset) { _, video in
                        previewCard(cover: video.cover, title: video.title, subtitle: video.uploader) {
                            openVideo(video)
                        }
                    }
                    ForEach(folders) { folder in
                        let available = !folder.isUnavailable &&
                            (section != .subscriptions || folder.type == 11 || folder.type == 21)
                        previewCard(
                            cover: folder.cover ?? "", title: folder.title,
                            subtitle: available ? "\(folder.kindLabel) · \(folder.mediaCount ?? 0) 个视频" : "暂不可用"
                        ) { openFolder(folder) }
                        .disabled(!available)
                        .opacity(available ? 1 : 0.5)
                    }
                }
            }
        }
        .padding(.bottom, 16)
        .task(id: "\(session.isLogin)-\(session.cookieString)-\(retry)") {
            await load()
        }
    }

    private func message(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 100)
    }

    private func carousel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12, content: content)
                .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
    }

    private func previewCard(cover: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                CachedAsyncImage(url: URL(string: cover.replacingOccurrences(of: "http://", with: "https://"))) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color(.systemGray5))
                    }
                }
                .frame(width: 160, height: 100)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(title).font(.subheadline).lineLimit(2, reservesSpace: true)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: 160, alignment: .leading)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
    }

    @MainActor
    private func load() async {
        generation += 1
        let requestGeneration = generation
        videos = []
        folders = []
        errorMessage = nil
        guard section != .offline, session.isLogin else { isLoading = false; return }
        isLoading = true
        defer { if generation == requestGeneration { isLoading = false } }
        do {
            switch section {
            case .history:
                let page = try await BiliAPI.shared.fetchHistoryList(type: "archive", ps: 20)
                guard generation == requestGeneration, !Task.isCancelled else { return }
                videos = Array((page.list ?? []).filter { $0.history?.business == "archive" }.prefix(6)).map { VideoItem(from: $0) }
            case .watchLater:
                let page = try await BiliAPI.shared.fetchWatchLaterList()
                guard generation == requestGeneration, !Task.isCancelled else { return }
                videos = Array((page.list ?? []).prefix(6)).map { VideoItem(from: $0) }
            case .subscriptions, .favorites:
                let page = try await LibraryService.folders(subscriptions: section == .subscriptions, page: 1)
                guard generation == requestGeneration, !Task.isCancelled else { return }
                folders = Array(page.entries.prefix(6))
            case .offline: break
            }
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            ErrorLogService.record(error, context: "加载我的页面预览")
        }
    }
}
