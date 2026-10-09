//
//  MyView.swift
//  PiliPod
//
//  Created by co on 2026/5/21.
//

import SwiftUI

struct MyView: View {
    var isActive = true
    @Bindable var messageViewModel: HomeViewModel
    @StateObject private var viewModel = MyViewModel()
    @ObservedObject private var loginSession = LoginSession.shared
    @State private var showLoginSheet = false
    @State private var showHistory = false
    @State private var showWatchLater = false
    @State private var showOfflineCache = false
    @State private var showSubscriptions = false
    @State private var showFavorites = false
    @State private var followingRoute: MyFollowingRoute?
    @ObservedObject private var pageSettings = MyPageSettingsStore.shared
    @State private var expandedSections: Set<MyPageSection> = []
    @State private var appliedDefaults = false
    @State private var selectedPreviewVideo: VideoItem?
    @State private var selectedPreviewFolder: LibraryFolder?
    @State private var selectedPreviewSource = ""
    @Namespace private var previewNamespace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部按钮
                    HStack {
                        Spacer()
                        NavigationLink {
                            MessageView(viewModel: messageViewModel)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .frame(width: 20, height: 20)
                                    .padding(10)
                                if messageViewModel.unreadMessageCount > 0 {
                                    Text(messageViewModel.unreadMessageCount > 99 ? "99+" : String(messageViewModel.unreadMessageCount))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 17, minHeight: 17)
                                        .background(.red, in: Capsule())
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .tint(.primary)
                        .accessibilityLabel("私信")
                        .accessibilityValue(messageViewModel.unreadMessageCount > 0 ? "未读消息 \(messageViewModel.unreadMessageCount) 条" : "无未读消息")
                        .accessibilityIdentifier("my.messages")
                        .glassEffect(.regular.interactive(), in: .circle)
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gear")
                                .frame(width: 20, height: 20)
                                .padding(10)
                        }
                        .tint(.primary)
                        .accessibilityLabel("设置")
                        .accessibilityIdentifier("my.settings")
                        .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 10)

                    headerView
                        .padding(.horizontal, 30)

                    VStack(spacing: 0) {
                        ForEach(pageSettings.settings.normalized.order) { section in
                            librarySection(section)
                            if section != pageSettings.settings.normalized.order.last {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    Spacer()
                }
            }
            .task {
                await viewModel.loadUser()
                await messageViewModel.refreshUnreadMessageCountIfNeeded()
            }
            .onAppear {
                if !appliedDefaults {
                    expandedSections = pageSettings.settings.expanded
                    appliedDefaults = true
                }
            }
            .onChange(of: pageSettings.settings.expanded) { _, defaults in
                expandedSections = defaults
            }
            .onChange(of: isActive) { _, active in
                if active { expandedSections = pageSettings.settings.expanded }
            }
            .onChange(of: loginSession.cookieString) { _, _ in
                selectedPreviewVideo = nil
                selectedPreviewFolder = nil
            }
            .navigationDestination(item: $selectedPreviewVideo) { video in
                VideoDetailPage(video: video, namespace: previewNamespace, onBack: { selectedPreviewVideo = nil })
                    .navigationTransition(.zoom(sourceID: selectedPreviewSource, in: previewNamespace))
            }
            .navigationDestination(item: $selectedPreviewFolder) { folder in
                LibraryMediaView(folder: folder)
                    .navigationTransition(.zoom(sourceID: selectedPreviewSource, in: previewNamespace))
            }
            .fullScreenCover(isPresented: $showLoginSheet) {
                LoginPageView()
            }
            .onReceive(loginSession.$isLogin) { isLogin in
                if isLogin {
                    Task {
                        await viewModel.loadUser()
                    }
                } else {
                    viewModel.user = nil
                }
            }
            .navigationDestination(isPresented: $showHistory) {
                HistoryView()
            }
            .navigationDestination(isPresented: $showOfflineCache) {
                OfflineCacheView(initialPrefill: nil)
            }
            .navigationDestination(isPresented: $showWatchLater) {
                WatchLaterView()
            }
            .navigationDestination(isPresented: $showSubscriptions) {
                LibraryFoldersView(subscriptions: true)
            }
            .navigationDestination(isPresented: $showFavorites) {
                LibraryFoldersView(subscriptions: false)
            }
            .navigationDestination(item: $followingRoute) { route in
                FollowingListView(mid: route.mid)
            }
        }
    }

    @ViewBuilder
    private var headerView: some View {
        if let user = viewModel.user {
            NavigationLink {
                UserSpaceView(mid: Int(user.mid))
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    CachedAsyncImage(url: URL(string: user.face)) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 8) {
                        Text(user.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        HStack(spacing: 12) {
                            Text("硬币 \(formattedMoney(user.money))")
                            Text("经验 \(user.levelInfo.currentExp)/\(maxExperienceText(for: user))")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        ProgressView(value: experienceProgress(for: user))
                            .tint(Color("BiliPink"))
                            .progressViewStyle(.linear)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
        } else {
            Group {
                if loginSession.isLogin {
                    loggedOutHeader
                } else {
                    Button {
                        showLoginSheet = true
                    } label: {
                        loggedOutHeader
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if let stat = viewModel.stat {
            HStack {
                Spacer()
                statItem(value: stat.dynamicCount, title: L10n.string("my.posts"))
                Spacer()
                if let user = viewModel.user {
                    Button {
                        followingRoute = MyFollowingRoute(mid: user.mid)
                    } label: {
                        statItem(value: stat.following, title: L10n.string("my.following"))
                    }
                    .buttonStyle(.plain)
                } else {
                    statItem(value: stat.following, title: L10n.string("my.following"))
                }
                Spacer()
                statItem(value: stat.follower, title:  L10n.string("my.followers"))
                Spacer()
            }
            .padding(.top, 2)
        } else {
            HStack {
                Spacer()
                statItem(value: 0, title: L10n.string("my.posts"))
                Spacer()
                statItem(value: 0, title: L10n.string("my.following"))
                Spacer()
                statItem(value: 0, title: L10n.string("my.followers"))
                Spacer()
            }
            .padding(.top, 2)
        }
    }

    private var loggedOutHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(loginSession.isLogin ? "正在加载个人信息…" : "点击登录")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("当前未登录账号")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func librarySection(_ section: MyPageSection) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    openFullList(section)
                } label: {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(section.title))
                            .font(.title2.weight(.bold))
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold)).foregroundStyle(.tertiary)
                        Spacer(minLength: 8)
                    }
                    .padding(.vertical, 16)
                    .frame(minHeight: 72)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(section.title)，查看全部")
                .accessibilityIdentifier("my.all.\(section.rawValue)")
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedSections.contains(section) { expandedSections.remove(section) }
                        else { expandedSections.insert(section) }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .rotationEffect(.degrees(expandedSections.contains(section) ? 90 : 0))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30, height: 30)
                        .background(Color(.tertiarySystemFill), in: Circle())
                        .frame(width: 44, height: 72)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("\(section.title)，\(expandedSections.contains(section) ? "收起" : "展开")")
                .accessibilityIdentifier("my.section.\(section.rawValue)")
                .accessibilityValue(expandedSections.contains(section) ? "已展开" : "已收起")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            if expandedSections.contains(section) {
                MyPagePreview(section: section, namespace: previewNamespace,
                    openVideo: { video, source in
                        selectedPreviewSource = source
                        selectedPreviewVideo = video
                    },
                    openFolder: { folder, source in
                        selectedPreviewSource = source
                        selectedPreviewFolder = folder
                    })
                    .transition(.opacity)
            }
        }
    }

    private func openFullList(_ section: MyPageSection) {
        switch section {
        case .offline: showOfflineCache = true
        case .history: showHistory = true
        case .subscriptions: showSubscriptions = true
        case .watchLater: showWatchLater = true
        case .favorites: showFavorites = true
        }
    }

    private func maxExperienceText(for user: UserCard) -> String {
        if user.levelInfo.nextExp == "--" {
            return "--"
        }
        return user.levelInfo.nextExp
    }

    private func experienceProgress(for user: UserCard) -> Double {
        if user.levelInfo.nextExp == "--" {
            return 1
        }

        guard let nextExp = Double(user.levelInfo.nextExp) else {
            return 0
        }

        let minExp = Double(user.levelInfo.currentMin)
        let currentExp = Double(user.levelInfo.currentExp)
        let range = max(nextExp - minExp, 1)
        let progress = (currentExp - minExp) / range
        return min(max(progress, 0), 1)
    }

    private func formattedMoney(_ money: Double) -> String {
        if money.rounded() == money {
            return String(Int(money))
        }
        return money.formatted(.number.precision(.fractionLength(0 ... 1)))
    }

    private func statItem(value: Int, title: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 44)
    }

}

#Preview {
    MyView(messageViewModel: HomeViewModel())
}

private struct MyFollowingRoute: Identifiable, Hashable {
    let mid: Int

    var id: Int { mid }
}
