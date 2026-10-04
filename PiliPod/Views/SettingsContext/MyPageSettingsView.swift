import SwiftUI

struct MyPageSettingsView: View {
    @ObservedObject private var store = MyPageSettingsStore.shared

    var body: some View {
        List {
            Section {
                ForEach(store.settings.normalized.order) { section in
                    Toggle(isOn: Binding(
                        get: { store.settings.expanded.contains(section) },
                        set: { enabled in
                            if enabled { store.settings.expanded.insert(section) }
                            else { store.settings.expanded.remove(section) }
                        }
                    )) {
                        Label(LocalizedStringKey(section.title), systemImage: section.symbol)
                    }
                    .accessibilityIdentifier("my.settings.\(section.rawValue)")
                }
                .onMove { source, destination in
                    var order = store.settings.normalized.order
                    order.move(fromOffsets: source, toOffset: destination)
                    store.settings.order = order
                }
            } header: {
                Text("条目顺序与默认展开")
            } footer: {
                Text("拖动右侧手柄调整顺序。打开开关后，进入“我的”页面时自动展开该条目。每项最多预览 6 个内容。")
            }
            Section {
                Button("恢复默认") { store.settings = MyPageSettings() }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("我的页面")
        .navigationBarTitleDisplayMode(.inline)
    }
}
