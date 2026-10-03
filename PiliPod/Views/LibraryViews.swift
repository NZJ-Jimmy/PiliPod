import SwiftUI

struct LibraryFoldersView: View {
    let subscriptions: Bool
    @StateObject private var model: LibraryViewModel<LibraryFolder>
    @ObservedObject private var session = LoginSession.shared
    @State private var showLogin = false
    @State private var pendingUnsubscribe: LibraryFolder?
    @State private var isUnsubscribing = false
    @State private var toastMessage: String?

    init(subscriptions: Bool) {
        self.subscriptions = subscriptions
        _model = StateObject(wrappedValue: LibraryViewModel(loader: { page in
            try await LibraryService.folders(subscriptions: subscriptions, page: page)
        }))
    }

    var body: some View {
        ScrollView {
            if !session.isLogin {
                LibraryLoginPrompt(showLogin: $showLogin)
            } else {
                LazyVStack(spacing: 0) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 16)], spacing: 20) {
                        ForEach(model.entries) { folder in
                            Group {
                                if folder.isUnavailable || (subscriptions && folder.type != 11 && folder.type != 21) {
                                    folderCard(folder)
                                        .opacity(0.5)
                                } else {
                                    NavigationLink {
                                        LibraryMediaView(folder: folder)
                                    } label: {
                                        folderCard(folder)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .contextMenu {
                                if subscriptions, folder.type == 11 || folder.type == 21 {
                                    Button("取消订阅", systemImage: "bookmark.slash", role: .destructive) {
                                        pendingUnsubscribe = folder
                                    }
                                    .disabled(isUnsubscribing)
                                }
                            }
                        }
                    }
                    .padding(16)

                    LibraryLoadingFooter(
                        isLoading: model.isLoading, error: model.errorMessage,
                        isEmpty: model.entries.isEmpty, hasMore: model.hasMore,
                        emptyText: subscriptions ? "暂无订阅的合集或收藏夹" : "暂无收藏夹",
                        load: { await model.loadMore() }
                    )
                }
            }
        }
        .refreshable { if session.isLogin { await model.refresh() } }
        .navigationTitle(subscriptions ? "我的订阅" : "我的收藏")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: "\(session.isLogin)-\(session.cookieString)") {
            model.reset()
            if session.isLogin { await model.loadMore() }
        }
        .onChange(of: session.isLogin) { _, loggedIn in
            if !loggedIn { model.reset() }
        }
        .fullScreenCover(isPresented: $showLogin) { LoginPageView() }
        .confirmationDialog("确定取消订阅吗？", isPresented: Binding(
            get: { pendingUnsubscribe != nil },
            set: { if !$0 { pendingUnsubscribe = nil } }
        ), titleVisibility: .visible) {
            if let folder = pendingUnsubscribe {
                Button("取消订阅", role: .destructive) {
                    unsubscribe(folder)
                }
            }
            Button("保留订阅", role: .cancel) { pendingUnsubscribe = nil }
        }
        .toast(message: $toastMessage)
    }

    private func folderCard(_ folder: LibraryFolder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LibraryCover(url: folder.cover)
                .aspectRatio(16 / 10, contentMode: .fit)
                .overlay(alignment: .bottomTrailing) {
                    Text(subscriptions ? folder.kindLabel : (folder.isPrivate ? "私密" : "公开"))
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(folder.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if subscriptions, let owner = folder.upper?.name {
                Text(owner).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(folder.isUnavailable ? "已失效" : "\(folder.mediaCount ?? 0) 个视频")
                .font(.caption).foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
    }

    private func unsubscribe(_ folder: LibraryFolder) {
        guard !isUnsubscribing else { return }
        isUnsubscribing = true
        let cookie = session.cookieString
        Task {
            defer { isUnsubscribing = false }
            do {
                try await LibraryService.unsubscribe(folder)
                guard cookie == session.cookieString else { return }
                model.remove(id: folder.id)
                toastMessage = "已取消订阅"
            } catch {
                toastMessage = error.localizedDescription
            }
        }
    }
}

struct LibraryMediaView: View {
    let folder: LibraryFolder
    @StateObject private var model: LibraryViewModel<LibraryMedia>
    @ObservedObject private var session = LoginSession.shared
    @Namespace private var videoNamespace
    @State private var selectedVideo: VideoItem?
    @State private var showLogin = false

    init(folder: LibraryFolder) {
        self.folder = folder
        _model = StateObject(wrappedValue: LibraryViewModel(loader: { page in
            try await LibraryService.media(folder: folder, page: page)
        }))
    }

    var body: some View {
        List {
            if !session.isLogin {
                LibraryLoginPrompt(showLogin: $showLogin)
                    .libraryRow()
            } else {
                Section {
                    HStack(spacing: 14) {
                        LibraryCover(url: folder.cover)
                            .frame(width: 100, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(folder.title).font(.headline)
                            Text("\(folder.kindLabel) · \(folder.mediaCount ?? 0) 个视频")
                                .font(.caption).foregroundStyle(.secondary)
                            if let owner = folder.upper?.name {
                                Text(owner).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    if let intro = folder.intro, !intro.isEmpty {
                        Text(intro).font(.subheadline).foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }
                }
                .libraryRow()

                ForEach(model.entries) { media in
                    if let video = media.video {
                        VideoCardSingleView(video: video, progress: nil, namespace: videoNamespace,
                                            onTap: { selectedVideo = video })
                            .padding(.vertical, 6)
                            .libraryRow()
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "video.slash").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(media.title ?? "已失效视频").lineLimit(2)
                                Text("内容已失效或暂不支持播放").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 12)
                        .libraryRow()
                    }
                }

                LibraryLoadingFooter(isLoading: model.isLoading, error: model.errorMessage,
                                     isEmpty: model.entries.isEmpty, hasMore: model.hasMore,
                                     emptyText: "暂无视频", load: { await model.loadMore() })
                    .libraryRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { if session.isLogin { await model.refresh() } }
        .navigationTitle(folder.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: "\(session.isLogin)-\(session.cookieString)") {
            model.reset()
            if session.isLogin { await model.loadMore() }
        }
        .onChange(of: session.isLogin) { _, loggedIn in
            if !loggedIn { model.reset(); selectedVideo = nil }
        }
        .fullScreenCover(isPresented: $showLogin) { LoginPageView() }
        .navigationDestination(item: $selectedVideo) { video in
            VideoDetailPage(video: video, namespace: videoNamespace, onBack: { selectedVideo = nil })
                .navigationTransition(.zoom(sourceID: "videoHero.\(video.bvid)", in: videoNamespace))
        }
    }
}

private struct LibraryCover: View {
    let url: String?

    var body: some View {
        CachedAsyncImage(url: URL(string: (url ?? "").replacingOccurrences(of: "http://", with: "https://"))) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                Rectangle().fill(Color(.secondarySystemBackground))
                    .overlay { Image(systemName: "folder.fill").font(.title).foregroundStyle(.secondary) }
            }
        }
        .clipped()
    }
}

private struct LibraryLoginPrompt: View {
    @Binding var showLogin: Bool
    var body: some View {
        ContentUnavailableView {
            Label("请先登录", systemImage: "person.crop.circle")
        } description: {
            Text("登录后查看你的收藏与订阅")
        } actions: {
            Button("登录") { showLogin = true }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }
}

private struct LibraryLoadingFooter: View {
    let isLoading: Bool
    let error: String?
    let isEmpty: Bool
    let hasMore: Bool
    let emptyText: String
    let load: () async -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView("加载中…")
            } else if let error {
                Text(error).font(.subheadline).foregroundStyle(.secondary)
                Button("重试") { Task { await load() } }.buttonStyle(.bordered)
            } else if isEmpty {
                ContentUnavailableView(emptyText, systemImage: "folder")
            } else if hasMore {
                ProgressView()
                    .onAppear { Task { await load() } }
            } else {
                Text("已经到底了").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: isEmpty ? 240 : 64)
        .padding(.horizontal, 16)
    }
}

private extension View {
    func libraryRow() -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
