import SwiftUI

#if canImport(UIKit)
import UIKit

/// Uses UIKit's own interactive transition, with a proxy that allows a custom
/// hidden back button while still rejecting root-page and in-flight pops.
struct NavigationPopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.enableSystemPopGestureIfPossible()
    }

    final class Controller: UIViewController {
        private weak var installedNavigationController: UINavigationController?
        private var originalDelegate: UIGestureRecognizerDelegate?
        private var delegateProxy: PopGestureDelegateProxy?
        private var remainingInstallAttempts = 3

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            remainingInstallAttempts = 3
            enableSystemPopGestureIfPossible()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enableSystemPopGestureIfPossible()
        }

        func enableSystemPopGestureIfPossible() {
            guard let navigationController = containingNavigationController(),
                  let gesture = navigationController.interactivePopGestureRecognizer
            else {
                guard remainingInstallAttempts > 0 else { return }
                remainingInstallAttempts -= 1
                DispatchQueue.main.async { [weak self] in
                    self?.installIfPossibleOnNextRunLoop()
                }
                return
            }

            if installedNavigationController !== navigationController {
                restorePreviousDelegate()
                installedNavigationController = navigationController
                originalDelegate = gesture.delegate
                let proxy = PopGestureDelegateProxy(
                    original: originalDelegate,
                    navigationController: navigationController
                )
                delegateProxy = proxy
                gesture.delegate = proxy
            }
            gesture.isEnabled = true
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-dynamic-feed-ui-testing") {
                print("DynamicNav installed: stack=\(navigationController.viewControllers.count), gesture=\(type(of: gesture)), enabled=\(gesture.isEnabled)")
            }
#endif
        }

        private func installIfPossibleOnNextRunLoop() {
            enableSystemPopGestureIfPossible()
        }

        private func containingNavigationController() -> UINavigationController? {
            if let navigationController { return navigationController }
            var controller: UIViewController? = self
            while let current = controller {
                if let navigationController = current.navigationController {
                    return navigationController
                }
                controller = current.parent
            }
            // SwiftUI can host the representable in a separate controller;
            // its displayed view still belongs to the navigation responder chain.
            var responder: UIResponder? = view
            while let current = responder {
                if let navigation = current as? UINavigationController { return navigation }
                if let controller = current as? UIViewController, let navigation = controller.navigationController {
                    return navigation
                }
                responder = current.next
            }
            return nil
        }

        private func restorePreviousDelegate() {
            guard let navigationController = installedNavigationController,
                  let gesture = navigationController.interactivePopGestureRecognizer,
                  gesture.delegate === delegateProxy
            else { return }
            gesture.delegate = originalDelegate
            delegateProxy = nil
            originalDelegate = nil
        }

        deinit {
            restorePreviousDelegate()
        }
    }
}

private final class PopGestureDelegateProxy: NSObject, UIGestureRecognizerDelegate {
    weak var original: UIGestureRecognizerDelegate?
    weak var navigationController: UINavigationController?

    init(original: UIGestureRecognizerDelegate?, navigationController: UINavigationController) {
        self.original = original
        self.navigationController = navigationController
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-dynamic-feed-ui-testing") {
            print("DynamicNav begin: stack=\(navigationController?.viewControllers.count ?? 0), transitioning=\(navigationController?.transitionCoordinator != nil)")
        }
#endif
        guard let navigationController,
              navigationController.viewControllers.count > 1,
              navigationController.transitionCoordinator == nil,
              !navigationController.isBeingDismissed
        else { return false }

        // UIKit's original delegate may reject a hidden system back button.
        // The player supplies its own back control, so that veto would disable
        // edge-pop even though the stack is eligible for an interactive return.
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        original?.gestureRecognizer?(
            gestureRecognizer,
            shouldRecognizeSimultaneouslyWith: otherGestureRecognizer
        ) ?? false
    }
}
#else
struct NavigationPopGestureEnabler: View {
    var body: some View { EmptyView() }
}
#endif
