import SwiftUI

private struct ConversationScrollSnapshot: Equatable {
    let height: CGFloat
    let contentHeight: CGFloat
    let offset: CGFloat
    let atBottom: Bool
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
    @State private var dragBoundary: CGFloat?
    @State private var position = ScrollPosition(idType: String.self)
    @State private var snapshot: ConversationScrollSnapshot?
    @State private var prependSnapshot: ConversationScrollSnapshot?
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
            }
            .scrollTargetLayout()
            .padding(.horizontal, 12).padding(.vertical, 12)
        }
        .scrollPosition($position)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("conversation.messages")
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .onScrollPhaseChange { _, phase in
            isUserScrolling = phase == .tracking || phase == .interacting || phase == .decelerating
        }
        .onScrollGeometryChange(for: ConversationScrollSnapshot.self) { geometry in
            ConversationScrollSnapshot(height: geometry.containerSize.height,
                contentHeight: geometry.contentSize.height,
                offset: geometry.contentOffset.y + geometry.contentInsets.top,
                atBottom: geometry.contentOffset.y + geometry.containerSize.height >=
                    geometry.contentSize.height + geometry.contentInsets.bottom - 24)
        } action: { old, new in
            snapshot = new
            if let saved = prependSnapshot, old.contentHeight != new.contentHeight {
                // Restore the visible pixel offset, not just the first row's top edge.
                prependSnapshot = nil
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    position.scrollTo(y: max(0, saved.offset + new.contentHeight - saved.contentHeight))
                }
            } else if isUserScrolling && old.height == new.height {
                followsLatest = new.atBottom
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _ in
            if followsLatest, dragBoundary == nil {
                Task { @MainActor in
                    await Task.yield()
                    if followsLatest, dragBoundary == nil { scrollToLatest(animated: false) }
                }
            }
        }
        .onChange(of: model.scrollRequest) { _, request in
            guard let request else { return }
            followsLatest = true
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) { position.scrollTo(id: request, anchor: .bottom) }
            model.scrollRequest = nil
        }
        .onChange(of: model.rows.last?.id) { _, _ in
            if followsLatest && !model.isLoadingHistory { scrollToLatest(animated: true) }
        }
        .onAppear { scrollToLatest(animated: false) }
        .simultaneousGesture(panelDismissGesture)
    }

    private func scrollToLatest(animated: Bool) {
        guard let id = model.rows.last?.id else { return }
        withAnimation(animated && !reduceMotion ? .smooth(duration: 0.22) : nil) {
            position.scrollTo(id: id, anchor: .bottom)
        }
    }

    @MainActor private func loadHistory() async {
        followsLatest = false
        // Capture after the loading indicator has appeared; it has the same fixed height.
        let saved = snapshot
        await model.loadOlderMessages()
        if model.historyError == nil { prependSnapshot = saved }
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
