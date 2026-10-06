import SwiftUI

private struct ConversationScrollSnapshot: Equatable {
    let height: CGFloat
    let contentHeight: CGFloat
    let offset: CGFloat
}

struct MessageTimelineView: View {
    @ObservedObject var model: ConversationViewModel
    @Binding var inputPanel: ConversationInputPanel?
    @Binding var isPanelExpanded: Bool
    @Binding var panelDismissal: CGFloat
    let panelTop: CGFloat
    let heroNamespace: Namespace.ID
    let onImage: (PrivateMessageImagePayload) -> Void
    let onVideo: (VideoItem) -> Void
    @State private var followsLatest = true
    @State private var isUserScrolling = false
    @State private var bottomIsVisible = false
    @State private var dragBoundary: CGFloat?
    @State private var position = ScrollPosition(idType: String.self)
    @State private var snapshot: ConversationScrollSnapshot?
    @State private var visibleFrames: [String: CGRect] = [:]
    @State private var historyAnchor: (id: String, y: CGFloat)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if model.isLoading {
            ProgressView("加载消息中…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.errorMessage, model.rows.isEmpty {
            ContentUnavailableView {
                Label("消息加载失败", systemImage: "exclamationmark.triangle")
            } description: { Text(error) } actions: {
                Button("重试") { Task { await model.loadMessages() } }
            }
        } else if model.rows.isEmpty {
            ContentUnavailableView("暂无消息", systemImage: "bubble.left.and.bubble.right")
        } else {
            timeline
        }
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if model.hasMoreHistory {
                    Button {
                        Task { await loadHistory() }
                    } label: {
                        if model.isLoadingHistory { ProgressView() }
                        else { Text(model.historyError == nil ? "加载更早消息" : "加载失败，点此重试").font(.caption) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(model.isLoadingHistory)
                    .accessibilityIdentifier("conversation.history")
                }
                ForEach(model.rows) { row in
                    MessageRow(row: row, emotionURLs: model.emotionURLs, heroNamespace: heroNamespace,
                        onImage: onImage, onVideo: onVideo)
                        .id(row.id)
                }
                Color.clear.frame(height: 1)
                    .onScrollVisibilityChange(threshold: 1) { bottomIsVisible = $0 }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 12).padding(.vertical, 12)
        }
        .scrollPosition($position)
        .coordinateSpace(name: "message.timeline")
        .onPreferenceChange(MessageFramePreferenceKey.self) { visibleFrames = $0 }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("conversation.messages")
        #if DEBUG
        .accessibilityValue(ConversationUITestFixture.enabled
            ? "following=\(followsLatest); bottomVisible=\(bottomIsVisible); userScrolling=\(isUserScrolling)" : "")
        #endif
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .onScrollPhaseChange { _, phase in
            let wasUserScrolling = isUserScrolling
            isUserScrolling = phase == .tracking || phase == .interacting || phase == .decelerating
            if phase == .interacting { followsLatest = false }
            if isUserScrolling && model.isLoadingHistory { historyAnchor = nil }
            if phase == .idle, wasUserScrolling {
                Task { @MainActor in
                    // Let the end marker's visibility settle after deceleration.
                    await Task.yield()
                    guard !isUserScrolling, historyAnchor == nil, dragBoundary == nil else { return }
                    followsLatest = bottomIsVisible
                    if followsLatest { scrollToLatest(animated: false) }
                }
            }
        }
        .onScrollGeometryChange(for: ConversationScrollSnapshot.self) { geometry in
            ConversationScrollSnapshot(height: geometry.containerSize.height,
                contentHeight: geometry.contentSize.height,
                offset: geometry.contentOffset.y + geometry.contentInsets.top)
        } action: { old, new in
            snapshot = new
            if followsLatest, !isUserScrolling, historyAnchor == nil, dragBoundary == nil,
               old.contentHeight != new.contentHeight {
                scrollToLatest(animated: false)
            }
        }
        .onChange(of: bottomIsVisible) { _, visible in
            // Visibility can arrive a frame after the idle scroll phase.
            if visible, !followsLatest, !isUserScrolling, !model.isLoadingHistory,
               historyAnchor == nil, dragBoundary == nil {
                followsLatest = true
                scrollToLatest(animated: false)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _ in
            if followsLatest, !isUserScrolling, dragBoundary == nil {
                Task { @MainActor in
                    await Task.yield()
                    if followsLatest, !isUserScrolling, dragBoundary == nil { scrollToLatest(animated: false) }
                }
            }
        }
        .onChange(of: model.scrollRequest) { _, request in
            guard request != nil else { return }
            historyAnchor = nil
            followsLatest = true
            scrollToLatest(animated: true)
            model.scrollRequest = nil
        }
        .onChange(of: model.rows.last?.id) { _, _ in
            if followsLatest && !model.isLoadingHistory { scrollToLatest(animated: true) }
        }
        .onAppear { scrollToLatest(animated: false) }
        .simultaneousGesture(panelDismissGesture)
    }

    private func scrollToLatest(animated: Bool) {
        guard !model.rows.isEmpty else { return }
        withAnimation(animated && !reduceMotion ? .smooth(duration: 0.22) : nil) {
            position.scrollTo(edge: .bottom)
        }
    }

    @MainActor private func loadHistory() async {
        guard !model.isLoadingHistory, model.hasMoreHistory else { return }
        followsLatest = false
        if let height = snapshot?.height,
           let visible = visibleFrames.filter({ $0.value.maxY > 0 && $0.value.minY < height })
            .min(by: { $0.value.minY < $1.value.minY }) {
            historyAnchor = (visible.key, visible.value.minY)
        }
        await model.loadOlderMessages()
        guard model.historyError == nil, let anchor = historyAnchor else { historyAnchor = nil; return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { position.scrollTo(id: anchor.id, anchor: .top) }
        // Lazy stacks estimate unrendered heights. Correct using the actual bubble frame,
        // including any timestamp/group boundary changes caused by the prepended page.
        for _ in 0..<10 {
            try? await Task.sleep(for: .milliseconds(20))
            guard historyAnchor != nil, let frame = visibleFrames[anchor.id], let snapshot else { break }
            let delta = frame.minY - anchor.y
            if abs(delta) < 0.5 { break }
            withTransaction(transaction) { position.scrollTo(y: max(0, snapshot.offset + delta)) }
        }
        historyAnchor = nil
    }

    private var panelDismissGesture: some Gesture {
        DragGesture(coordinateSpace: .named("conversation"))
            .onChanged { value in
                guard inputPanel != nil, value.translation.height > 0 else { return }
                if dragBoundary == nil { dragBoundary = panelTop }
                let distance = max(0, value.location.y - (dragBoundary ?? panelTop))
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { panelDismissal = distance }
            }
            .onEnded { value in
                guard dragBoundary != nil else { return }
                let projected = panelDismissal + max(0, value.predictedEndTranslation.height - value.translation.height)
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                    if panelDismissal > 0 && projected > 80 {
                        inputPanel = nil
                        isPanelExpanded = false
                    }
                    panelDismissal = 0
                    dragBoundary = nil
                }
            }
    }
}
