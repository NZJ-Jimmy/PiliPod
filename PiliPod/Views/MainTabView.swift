//
//  MainTabView.swift
//  PiliPod
//
//  Created by co on 2026/5/21.
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var homeViewModel = HomeViewModel()
    @State private var selectedTab: MainTab = .home
    @State private var searchText = ""
    @State private var searchSubmissionID = 0
    @FocusState private var searchFieldFocused: Bool
    @State private var profileTabAvatar: UIImage?
    @ObservedObject private var loginSession = LoginSession.shared

    private enum MainTab: Hashable {
        case home
        case dynamic
        case mine
        case search
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("首页", systemImage: "house.fill", value: MainTab.home) {
                HomeView(viewModel: homeViewModel)
            }

            Tab(value: MainTab.dynamic) {
                DynamicView()
            } label: {
                Image("DynamicIcon").renderingMode(.template)
                Text("动态")
            }

            Tab(value: MainTab.mine) {
                MyView(isActive: selectedTab == .mine, messageViewModel: homeViewModel)
            } label: {
                profileTabIcon
                Text("我的")
            }

            Tab("搜索", systemImage: "magnifyingglass", value: MainTab.search, role: .search) {
                NavigationStack {
                    SearchView(
                        searchSubmissionID: searchSubmissionID,
                        searchText: $searchText,
                        isSearchFieldFocused: Binding(
                            get: { searchFieldFocused },
                            set: { searchFieldFocused = $0 }
                        )
                    )
                }
                .searchable(text: $searchText, prompt: "搜索视频")
                .searchFocused($searchFieldFocused)
                .onSubmit(of: .search) { searchSubmissionID += 1 }
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .toolbar(.visible, for: .tabBar)
        .task {
            await homeViewModel.loadUserIfNeeded()
            await homeViewModel.loadUnreadMessageCount(force: true)
        }
        .task(id: homeViewModel.userFace) {
            guard let face = homeViewModel.userFace,
                  let url = URL(string: face),
                  let image = await SharedRemoteImageStore.shared.image(for: url)
            else {
                profileTabAvatar = nil
                return
            }
            profileTabAvatar = tabBarAvatar(from: image)
        }
        .onReceive(loginSession.$isLogin) { isLogin in
            if isLogin {
                Task {
                    await homeViewModel.loadUserIfNeeded()
                    await homeViewModel.loadUnreadMessageCount(force: true)
                }
            } else {
                homeViewModel.userFace = nil
                profileTabAvatar = nil
                Task { await homeViewModel.loadUnreadMessageCount(force: true) }
            }
        }
        .onChange(of: selectedTab) { newTab in
            searchFieldFocused = newTab == .search
            guard newTab == .mine else { return }
            Task {
                await homeViewModel.refreshUnreadMessageCountIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .manualPictureInPictureRestoreRequested)) { notification in
            selectedTab = .home
            // Deliver a second event after the tab transition has committed.
            // This makes restoration work even when the user was in My/UserSpace.
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .manualPictureInPictureRestoreOnHome,
                    object: notification.object
                )
            }
        }
    }

    private var profileTabIcon: Image {
        if loginSession.isLogin, let profileTabAvatar {
            Image(uiImage: profileTabAvatar.withRenderingMode(.alwaysOriginal))
                .renderingMode(.original)
        } else {
            Image(systemName: "person.circle")
        }
    }

    private func tabBarAvatar(from image: UIImage) -> UIImage {
        let iconSize = CGSize(width: 28, height: 28)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        return UIGraphicsImageRenderer(size: iconSize, format: format).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: iconSize)).addClip()

            let scale = max(iconSize.width / image.size.width, iconSize.height / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(
                x: (iconSize.width - size.width) / 2,
                y: (iconSize.height - size.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: size))
        }
    }
}

#Preview {
    MainTabView()
}
