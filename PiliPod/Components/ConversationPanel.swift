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
                let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
                withAnimation(duration > 0 ? .easeOut(duration: duration) : nil) {
                    self?.isVisible = height > 0
                    if height > 100 { self?.lastHeight = height }
                }
            }
        }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}

struct ConversationPanel<Content: View>: View {
    let height: CGFloat
    let maximumHeight: CGFloat
    @Binding var expanded: Bool
    let dismissal: CGFloat
    let onDismiss: () -> Void
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0
    @State private var dragOrigin: CGFloat?

    init(height: CGFloat, maximumHeight: CGFloat, expanded: Binding<Bool>, dismissal: CGFloat = 0,
         onDismiss: @escaping () -> Void = {}, @ViewBuilder content: () -> Content) {
        self.height = height
        self.maximumHeight = maximumHeight
        _expanded = expanded
        self.dismissal = dismissal
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.secondary.opacity(0.55)).frame(width: 54, height: 5)
                .frame(maxWidth: .infinity).frame(height: 28).contentShape(Rectangle())
                .gesture(DragGesture(coordinateSpace: .global).onChanged { value in
                        if dragOrigin == nil { dragOrigin = expanded ? maximumHeight : height }
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { drag = value.translation.height }
                    }
                    .onEnded { value in
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                            if !expanded && value.predictedEndTranslation.height > height * 0.45 {
                                onDismiss()
                            } else if value.predictedEndTranslation.height < -35 { expanded = true }
                            else if value.predictedEndTranslation.height > 35 { expanded = false }
                            drag = 0
                            dragOrigin = nil
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
            // Keep the native picker/scroll content stable during the finger-driven resize.
            content.frame(height: max(0, (expanded ? maximumHeight : height) - 28))
        }
        .frame(height: max(0, min(maximumHeight,
            (dragOrigin ?? (expanded ? maximumHeight : height)) - drag) - dismissal), alignment: .top)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .padding(.horizontal, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("conversation.panel")
    }
}
