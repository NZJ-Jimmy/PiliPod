import SwiftUI

struct DynamicAuthorAvatar: View {
    let face: String?
    var isAll = false

    var body: some View {
        CachedAsyncImage(url: face.flatMap { URL(string: $0.hasPrefix("//") ? "https:\($0)" : $0) }) { phase in
            if case let .success(image) = phase, !isAll {
                image.resizable().scaledToFill()
            } else {
                Circle().fill(Color(.tertiarySystemFill))
                    .overlay {
                        Image(systemName: isAll ? "person.2.fill" : "person.fill")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct DynamicAuthorPicker: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DynamicAuthorPickerModel
    @State private var searchText = ""
    let selectedMID: Int?
    let onSelect: (DynamicFeedAuthor?) -> Void

    init(mid: Int, selectedMID: Int?, onSelect: @escaping (DynamicFeedAuthor?) -> Void) {
        _viewModel = StateObject(wrappedValue: DynamicAuthorPickerModel(mid: mid))
        self.selectedMID = selectedMID
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    select(nil)
                } label: {
                    HStack {
                        Label("全部 UP 主", systemImage: "person.2.fill")
                        Spacer()
                        if selectedMID == nil { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                    }
                }
                .foregroundStyle(.primary)

                Section("已关注的 UP 主") {
                    ForEach(viewModel.users) { user in
                        Button {
                            select(DynamicFeedAuthor(mid: user.mid, uname: user.uname, face: user.face, hasUpdate: nil))
                        } label: {
                            HStack(spacing: 12) {
                                DynamicAuthorAvatar(face: user.face).frame(width: 40, height: 40)
                                Text(user.uname).lineLimit(1)
                                Spacer()
                                if selectedMID == user.mid {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                    }
                    if viewModel.isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if let error = viewModel.errorMessage {
                        Text(error).font(.subheadline).foregroundStyle(.secondary)
                        Button("重试") { Task { await viewModel.loadMore() } }
                    } else if viewModel.users.isEmpty {
                        Text(searchText.isEmpty ? "还没有关注的 UP 主" : "没有找到匹配的 UP 主")
                            .foregroundStyle(.secondary)
                    } else if viewModel.hasMore {
                        Button("加载更多 UP 主") { Task { await viewModel.loadMore() } }
                            .onAppear { Task { await viewModel.loadMore() } }
                    }
                }
            }
            .navigationTitle("选择 UP 主")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索已关注的 UP 主")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task(id: searchText) {
                viewModel.prepareSearch(searchText)
                if !searchText.isEmpty {
                    do { try await Task.sleep(for: .milliseconds(300)) }
                    catch { return }
                }
                await viewModel.loadMore()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func select(_ author: DynamicFeedAuthor?) {
        onSelect(author)
        dismiss()
    }
}
