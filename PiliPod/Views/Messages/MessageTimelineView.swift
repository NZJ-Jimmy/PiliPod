import SwiftUI

private struct ConversationScrollSnapshot: Equatable {
    let height: CGFloat
    let offset: CGFloat
}

private struct ConversationBottomPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
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
    @State private var bottomY: CGFloat?
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
                        .background {
                            if row.id == model.rows.last?.id {
                                GeometryReader { geometry in
                                    Color.clear.preference(key: ConversationBottomPreferenceKey.self,
                                        value: geometry.frame(in: .named("message.timeline")).maxY)
                                }
                            }
                        }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 12).padding(.vertical, 12)
        }
        .scrollPosition($position)
        .coordinateSpace(name: "message.timeline")
        .onPreferenceChange(MessageFramePreferenceKey.self) { visibleFrames = $0 }
        .onPreferenceChange(ConversationBottomPreferenceKey.self) {
            bottomY = $0
            restoreFollowingIfAtBottom()
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("conversation.messages")
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(followsLatest ? .bottom : nil, for: .sizeChanges)
        .onScrollPhaseChange { _, phase in
            let wasUserScrolling = isUserScrolling
            isUserScrolling = phase == .tracking || phase == .interacting || phase == .decelerating
            if phase == .interacting { followsLatest = false }
            if isUserScrolling && model.isLoadingHistory { historyAnchor = nil }
            if phase == .idle, wasUserScrolling {
                if historyAnchor == nil, dragBoundary == nil {
                    followsLatest = bottomIsVisible
                }
            }
        }
        .onScrollGeometryChange(for: ConversationScrollSnapshot.self) { geometry in
            ConversationScrollSnapshot(height: geometry.containerSize.height,
                offset: geometry.contentOffset.y + geometry.contentInsets.top)
        } action: { _, new in
            snapshot = new
            restoreFollowingIfAtBottom()
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

    private var bottomIsVisible: Bool {
        guard let bottomY, let height = snapshot?.height else { return false }
        return bottomY > 0 && bottomY <= height + 1
    }

    private func restoreFollowingIfAtBottom() {
        guard !followsLatest, bottomIsVisible, !isUserScrolling, !model.isLoadingHistory,
              historyAnchor == nil, dragBoundary == nil else { return }
        followsLatest = true
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
