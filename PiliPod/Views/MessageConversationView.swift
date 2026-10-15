//
//  MessageConversationView.swift
//  PiliPod
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct MessageConversationView: View {
    let session: PrivateMessageSession
    @StateObject private var keyboard = ConversationKeyboard()

    @StateObject private var model: ConversationViewModel
    @State private var inputPanel: ConversationInputPanel?
    @State private var isPanelExpanded = false
    @State private var panelDismissal: CGFloat = 0
    @State private var panelTop: CGFloat = 0
    @State private var composerHeight: CGFloat = 62
    @State private var presentedImage: PrivateMessageImagePayload?
    @FocusState private var isInputFocused: Bool
    @State private var selectedVideo: VideoItem?
    @State private var selectedUserMID: Int?
    @Namespace private var videoHeroNamespace

    init(session: PrivateMessageSession) {
        self.session = session
        _model = StateObject(wrappedValue: ConversationViewModel(session: session))
    }
    private var isPanelShown: Bool { inputPanel != nil }
    private var composer: MessageComposer {
        MessageComposer(model: model, keyboard: keyboard, inputPanel: $inputPanel,
            isPanelExpanded: $isPanelExpanded, panelDismissal: $panelDismissal, focus: $isInputFocused)
    }
    private func dismissPanel() {
        inputPanel = nil
        isPanelExpanded = false
        panelDismissal = 0
    }

    var body: some View {
        GeometryReader { geometry in
          VStack(spacing: 0) {
            messageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if session.sessionType == 1 {
                composer
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { composerHeight = $0 }
                if isPanelShown {
                    ConversationPanel(height: keyboard.lastHeight, maximumHeight: max(0, min(geometry.size.height * 0.78, geometry.size.height - composerHeight - 44)),
                        expanded: $isPanelExpanded, dismissal: panelDismissal, onDismiss: dismissPanel) {
                        if inputPanel == .photos { composer.photoPanel }
                        else { composer.emotePanel }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("conversation")).minY } action: { panelTop = $0 }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
          }
        }
        .background(Color(.systemBackground))
        .coordinateSpace(name: "conversation")
        .ignoresSafeArea(.container, edges: .bottom)
        // Custom input panels occupy the keyboard's space. Only the system keyboard
        // contributes keyboard safe-area insets; never compensate with a second offset.
        .ignoresSafeArea(.keyboard, edges: isPanelShown ? .bottom : [])
        .safeAreaInset(edge: .top, spacing: 0) { conversationNavigationHeader }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedUserMID) { mid in
            UserSpaceView(mid: mid)
        }
        .navigationDestination(item: $selectedVideo) { video in
            if #available(iOS 18.0, *) {
                VideoDetailPage(
                    video: video,
                    namespace: videoHeroNamespace,
                    onBack: { selectedVideo = nil }
                )
                .navigationTransition(
                    .zoom(sourceID: "conversationVideo.\(video.bvid)", in: videoHeroNamespace)
                )
            } else {
                VideoDetailPage(
                    video: video,
                    namespace: videoHeroNamespace,
                    onBack: { selectedVideo = nil }
                )
            }
        }
        .task {
            await model.loadMessages()
            #if DEBUG
            if ConversationUITestFixture.enabled { return }
            #endif
            await model.loadEmotes()
        }
        .onChange(of: isInputFocused) { _, focused in
            if focused { inputPanel = nil; isPanelExpanded = false }
        }
        .task(id: model.photoSelections) { await model.preparePhotos() }
        .sensoryFeedback(.success, trigger: model.isSending) { old, new in
            old && !new && model.sendError == nil
        }
        .fullScreenCover(isPresented: Binding(
            get: { presentedImage != nil }, set: { if !$0 { presentedImage = nil } }
        )) {
            if let payload = presentedImage,
               let url = MessagePayload.url(from: payload.url) {
                FullscreenImageViewer(imageURL: url.absoluteString,
                    onDismiss: { presentedImage = nil })
            }
        }
        .alert("发送失败", isPresented: Binding(
            get: { model.sendError != nil }, set: { if !$0 { model.sendError = nil } }
        )) {
            Button("好的", role: .cancel) { model.sendError = nil }
        } message: {
            Text(model.sendError ?? "")
        }
    }

    private var conversationNavigationHeader: some View {
        conversationHeader.frame(maxWidth: .infinity)
            .padding(.top, -44)
            .background {
                Rectangle().fill(.ultraThinMaterial)
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                        .init(color: .black, location: 0.35), .init(color: .clear, location: 1)],
                        startPoint: .top, endPoint: .bottom))
                    .padding(.bottom, -24).ignoresSafeArea(edges: .top)
            }
    }

    private var conversationHeader: some View {
        Button {
            guard session.sessionType == 1, session.talkerID <= UInt64(Int.max) else { return }
            selectedUserMID = Int(session.talkerID)
        } label: {
            VStack(spacing: -2) {
                CachedAsyncImage(url: MessagePayload.url(from: session.avatarURL)) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.secondary.opacity(0.14))
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .accessibilityHidden(true)
                HStack(spacing: 4) {
                    Text(session.name).lineLimit(1)
                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).accessibilityHidden(true)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .glassEffect(.regular, in: Capsule())
            }
            .frame(maxWidth: 210)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .disabled(session.sessionType != 1)
    }

    private var messageContent: some View {
        MessageTimelineView(model: model, inputPanel: $inputPanel, isPanelExpanded: $isPanelExpanded,
            panelDismissal: $panelDismissal, panelTop: panelTop, heroNamespace: videoHeroNamespace,
            onImage: { presentedImage = $0 }, onVideo: { selectedVideo = $0 })
    }
}
