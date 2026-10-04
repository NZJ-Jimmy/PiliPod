import SwiftUI
import UIKit
import Combine

@MainActor
final class ConversationKeyboard: ObservableObject {
    @Published var lastHeight: CGFloat = 320
    @Published var isVisible = false
    var bottomInset: CGFloat {
        PiliPodAppDelegate.activeWindowScene?.windows.first(where: \.isKeyWindow)?.safeAreaInsets.bottom ?? 0
    }
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil, queue: .main) { [weak self] notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            MainActor.assumeIsolated {
                guard let window = PiliPodAppDelegate.activeWindowScene?.windows.first(where: \.isKeyWindow) else { return }
                let converted = window.convert(frame, from: window.screen.coordinateSpace)
                let height = window.bounds.intersection(converted).height
                self?.isVisible = height > 100
                if height > 100 { self?.lastHeight = height }
            }
        }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}

struct ConversationPanel<Content: View>: View {
    let height: CGFloat
    let maximumHeight: CGFloat
    @Binding var expanded: Bool
    let content: Content
    @GestureState private var drag: CGFloat = 0

    init(height: CGFloat, maximumHeight: CGFloat, expanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.height = height
        self.maximumHeight = maximumHeight
        _expanded = expanded
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.secondary.opacity(0.55)).frame(width: 54, height: 5)
                .frame(maxWidth: .infinity).frame(height: 28).contentShape(Rectangle())
                .gesture(DragGesture().updating($drag) { value, state, _ in state = value.translation.height }
                    .onEnded { value in
                        withAnimation(.snappy) {
                            if value.translation.height < -35 { expanded = true }
                            if value.translation.height > 35 { expanded = false }
                        }
                    })
                .accessibilityLabel("展开或收起面板")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: expanded = true
                    case .decrement: expanded = false
                    @unknown default: break
                    }
                }
            content.frame(maxHeight: .infinity)
        }
        .frame(height: min(maximumHeight, max(220, (expanded ? maximumHeight : height) - drag)))
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .padding(.horizontal, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("conversation.panel")
    }
}
