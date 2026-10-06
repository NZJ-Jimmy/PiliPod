import SwiftUI
import PhotosUI

/// Keep the embedded picker in its regular-height grid layout as its panel resizes.
/// Changing the picker to compact vertical traits also changes thumbnail columns.
struct ConversationPhotoPicker: UIViewControllerRepresentable {
    @Binding var selection: [PhotosPickerItem]
    let isDisabled: Bool

    func makeUIViewController(context: Context) -> UIHostingController<AnyView> {
        let controller = UIHostingController(rootView: picker)
        controller.traitOverrides.verticalSizeClass = .regular
        controller.safeAreaRegions = []
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<AnyView>, context: Context) {
        controller.rootView = picker
    }

    private var picker: AnyView {
        AnyView(
            PhotosPicker(selection: $selection, maxSelectionCount: 50,
                selectionBehavior: .continuous, matching: .images,
                preferredItemEncoding: .compatible) { EmptyView() }
                .photosPickerStyle(.inline)
                .photosPickerAccessoryVisibility(.hidden, edges: .all)
                .environment(\.verticalSizeClass, .regular)
                .disabled(isDisabled)
        )
    }
}
