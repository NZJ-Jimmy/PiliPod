import SwiftUI

struct DynamicView: View {
    @StateObject private var viewModel = DynamicViewModel()
    @ObservedObject private var session = LoginSession.shared
    @State private var showingAuthorPicker = false
    @State private var selectedVideo: VideoItem?
    @State private var selectedLiveRoom: LiveCardModel?
    @State private var selectedAuthorMID: Int?
    @State private var selectedDynamic: UserSpaceDynamicItem?
    @Namespace private var videoHeroNamespace

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filters
                ScrollView {
                    content
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
                .id(requestKey)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("动态")
            .refreshable {
                guard accountMID != nil else { return }
                await viewModel.refresh()
                await viewModel.refreshAuthors()
            }
            .task(id: requestKey) {
                guard accountMID != nil else { return }
                await viewModel.refresh()
            }
            .task(id: accountMID) {
                guard accountMID != nil else { return }
                await viewModel.refreshAuthors()
            }
            .onChange(of: accountMID) { _, _ in
                showingAuthorPicker = false
                viewModel.resetAccount()
            }
            .sheet(isPresented: $showingAuthorPicker) {
                if let mid = accountMID {
                    DynamicAuthorPicker(mid: mid, selectedMID: viewModel.selectedAuthor?.mid) {
                        viewModel.selectedAuthor = $0
                    }
                }
            }
            .navigationDestination(item: $selectedVideo) { video in
                VideoDetailPage(
                    video: video,
                    namespace: videoHeroNamespace,
                    onBack: { selectedVideo = nil }
                )
            }
            .navigationDestination(item: $selectedLiveRoom) { room in
                LivePlaybackPage(room: room)
            }
            .navigationDestination(item: $selectedAuthorMID) { mid in
                UserSpaceView(mid: mid)
            }
            .navigationDestination(item: $selectedDynamic) { dynamic in
                UserSpaceDynamicDetailView(
                    item: dynamic,
                    onVideoTap: openVideo,
                    onLiveTap: openLive,
                    onAuthorTap: { selectedAuthorMID = $0 }
                )
            }
        }
    }

    private var accountMID: Int? {
        guard session.isLogin else { return nil }
        return session.cookies.flatMap { Int($0.DedeUserID) }
    }

    private var requestKey: String {
        "\(accountMID ?? 0)/\(viewModel.category.apiType)/\(viewModel.selectedAuthor?.mid ?? 0)"
    }

    private var displayedAuthors: [DynamicFeedAuthor] {
        guard let selected = viewModel.selectedAuthor, !viewModel.authors.contains(where: { $0.mid == selected.mid }) else {
            return viewModel.authors
        }
        return [selected] + viewModel.authors
    }

    private var filters: some View {
        VStack(spacing: 12) {
            HStack {
                Text(viewModel.selectedAuthor?.uname ?? "全部 UP 主")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Button {
                    showingAuthorPicker = true
                } label: {
                    Label("全部关注", systemImage: "line.3.horizontal.decrease")
                        .font(.subheadline)
                }
                .disabled(accountMID == nil)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    authorButton(nil)
                    ForEach(displayedAuthors) { author in
                        authorButton(author)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)

            Picker("内容类别", selection: $viewModel.category) {
                ForEach(DynamicCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private func authorButton(_ author: DynamicFeedAuthor?) -> some View {
        let selected = viewModel.selectedAuthor?.mid == author?.mid
        return Button {
            viewModel.selectedAuthor = author
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    DynamicAuthorAvatar(face: author?.face, isAll: author == nil)
                        .frame(width: 48, height: 48)
                        .overlay {
                            Circle().stroke(selected ? Color.accentColor : .clear, lineWidth: 2)
                                .padding(-3)
                        }
                    if author?.hasUpdate == true {
                        Circle().fill(Color.accentColor).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    }
                }
                Text(author?.uname ?? "全部")
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(selected ? Color.accentColor : .primary)
            }
            .frame(width: 64)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(author?.uname ?? "全部 UP 主")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        if accountMID == nil {
            ContentUnavailableView("登录后查看动态", systemImage: "person.crop.circle", description: Text("登录后可按关注的 UP 主和内容类别查看动态。"))
        } else if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView("加载动态中…")
                .frame(maxWidth: .infinity, minHeight: 240)
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
            VStack(spacing: 12) {
                Text(error).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("重试") { Task { await viewModel.refresh() } }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        } else if viewModel.items.isEmpty {
            VStack(spacing: 12) {
                ContentUnavailableView(
                    viewModel.hasMore ? "尚未找到匹配动态" : "暂无匹配动态",
                    systemImage: "tray",
                    description: Text(viewModel.hasMore ? "可以继续查找更早的动态。" : "试试其他 UP 主或内容类别。")
                )
                if viewModel.hasMore {
                    Button("继续查找") { Task { await viewModel.loadMore() } }
                        .buttonStyle(.bordered)
                }
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.items) { item in
                    DynamicCardView(
                        item: item,
                        onVideoTap: openVideo,
                        onLiveTap: openLive,
                        onAuthorTap: { selectedAuthorMID = $0 },
                        onCommentTap: { _ in selectedDynamic = item },
                        onTapDetail: { selectedDynamic = item }
                    )
                    .onAppear { Task { await viewModel.loadMoreIfNeeded(current: item) } }
                }
                if viewModel.isLoading {
                    ProgressView().padding(.vertical, 8)
                } else if let error = viewModel.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    Button("重试加载") { Task { await viewModel.loadMore() } }
                        .buttonStyle(.bordered)
                } else if !viewModel.hasMore {
                    Text("没有更多动态").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
                } else {
                    Button("加载更多") { Task { await viewModel.loadMore() } }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func openVideo(_ video: UserSpaceDynamicItem.Video) {
        guard let bvid = video.bvid, !bvid.isEmpty else { return }
        selectedVideo = VideoItem(
            bvid: bvid, cid: nil, cover: video.coverURL ?? "", title: video.title,
            playCount: VideoItem.formatCount(video.playCount),
            danmakuCount: VideoItem.formatCount(video.danmakuCount), uploader: "",
            duration: video.duration, progressSeconds: nil, publishTimeText: "--",
            bottomRcmdReasonText: nil
        )
    }

    private func openLive(_ live: UserSpaceDynamicItem.Live) {
        selectedLiveRoom = LiveCardModel(
            roomId: live.roomID, uid: nil, title: live.title, coverURL: live.coverURL ?? "",
            onlineCount: live.onlineCount, anchorName: "", faceURL: "",
            areaName: live.areaName, badgeText: "直播中", link: live.link
        )
    }
}
