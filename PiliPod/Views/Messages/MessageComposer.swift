import SwiftUI
import PhotosUI

enum ConversationInputPanel { case photos, emotes }

struct MessageComposer: View {
    @ObservedObject var model: ConversationViewModel
    @ObservedObject var keyboard: ConversationKeyboard
    @Binding var inputPanel: ConversationInputPanel?
    @Binding var isPanelExpanded: Bool
    @Binding var panelDismissal: CGFloat
    var focus: FocusState<Bool>.Binding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                    inputPanel = inputPanel == .photos ? nil : .photos
                    
                    isPanelExpanded = false
                    panelDismissal = 0
                    focus.wrappedValue = false
                }
            } label: {
                if model.isPreparingPhoto { ProgressView().frame(width: 44, height: 44) }
                else { Image(systemName: "plus").font(.title3).dynamicTypeSize(...DynamicTypeSize.xxxLarge).frame(width: 44, height: 44) }
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44).contentShape(Circle())
            .accessibilityElement(children: .ignore)
            .glassEffect(.regular.interactive(), in: .circle)
            .disabled(model.isSending || model.isPreparingPhoto || model.isLoading || !model.canSend)
            .accessibilityLabel("选择照片")
            VStack(spacing: 0) {
              if !model.pendingPhotos.isEmpty { photoPreview }
              HStack(alignment: .bottom, spacing: 8) {
                TextField("消息", text: $model.inputText, axis: .vertical)
                    .focused(focus)
                    .lineLimit(1 ... 4)
                    .font(.body)
                    .frame(minHeight: 30)
                    .accessibilityIdentifier("conversation.input")
                        if model.pendingPhoto != nil || !model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button { Task { await model.sendMessage() } } label: {
                                Group {
                                    if model.isSending { ProgressView().tint(.white) }
                                    else { Image(systemName: "arrow.up") }
                                }
                                    .font(.body.weight(.bold)).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color.blue, in: Circle())
                                    .frame(width: 44, height: 44).contentShape(Rectangle()).padding(-7)
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isSending || model.isPreparingPhoto || model.isLoading || !model.canSend)
                            .accessibilityLabel(model.isSending ? "发送中" : "发送消息")
                            .accessibilityIdentifier("conversation.send")
                            .transition(.opacity)
                        }
                }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                    inputPanel = inputPanel == .emotes ? nil : .emotes
                    
                    isPanelExpanded = false
                    panelDismissal = 0
                    focus.wrappedValue = inputPanel != .emotes
                }
                if (inputPanel == .emotes) { Task { await model.loadEmotes() } }
            } label: {
                Image(systemName: (inputPanel == .emotes) ? "keyboard" : "face.smiling")
                    .font(.body.weight(.medium)).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44).contentShape(Circle())
            .accessibilityElement(children: .ignore)
            .disabled(model.isSending)
            .accessibilityLabel((inputPanel == .emotes) ? "显示键盘" : "选择表情")
            .foregroundStyle(.secondary)
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10 + ((inputPanel != nil) || keyboard.isVisible ? 0 : keyboard.bottomInset))
    }

    var photoPanel: some View {
            PhotosPicker(selection: $model.photoSelections, maxSelectionCount: 50, selectionBehavior: .continuous, matching: .images,
                preferredItemEncoding: .compatible) { EmptyView() }
                .photosPickerStyle(.inline)
                .photosPickerAccessoryVisibility(.hidden, edges: .all)
                .disabled(model.isSending)
    }

    var emotePanel: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack {
                    Button("Emoji") { model.selectedPackageID = nil }
                        .buttonStyle(.bordered)
                        .tint(model.selectedPackageID == nil ? .biliPink : .secondary)
                    ForEach(model.emotePackages) { package in
                        Button(package.text) { model.selectedPackageID = package.id }
                            .buttonStyle(.bordered)
                            .tint(model.selectedPackageID == package.id ? .biliPink : .secondary)
                    }
                }
            }
            .scrollIndicators(.hidden)
            if model.isLoadingEmotes { ProgressView("加载 B 站表情…") }
            if let emoteError = model.emoteError {
                HStack {
                    Text(emoteError).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Button("重试") { Task { await model.loadEmotes() } }
                }
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 4 : 7), spacing: 12) {
                    if let package = model.emotePackages.first(where: { $0.id == model.selectedPackageID }) {
                        ForEach(package.emote) { emote in
                            Button { model.inputText += emote.text } label: {
                                CachedAsyncImage(url: MessagePayload.url(from: emote.url)) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFit()
                                    } else {
                                        Text(emote.text).font(.caption2).lineLimit(2)
                                    }
                                }
                                .frame(width: 34, height: 34)
                                .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .accessibilityLabel(emote.text)
                        }
                    } else {
                        ForEach(Self.emoji, id: \.self) { emoji in
                            Button { model.inputText += emoji } label: {
                                Text(emoji).font(.largeTitle)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .accessibilityLabel(emoji)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(model.isSending)
        .padding(12)
        .padding(.bottom, 20)
    }

    private static let emoji = ["😀", "😁", "😂", "🤣", "😊", "🥰", "😍", "😘", "😎", "🤔", "😭", "🥺", "😅", "😆", "😉", "😋", "🤗", "😴", "😮", "😡", "👍", "👎", "👏", "🙏", "🤝", "💪", "✌️", "❤️", "💔", "💕", "🔥", "🎉", "✨", "🌹", "🍻"]

    private var photoPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(model.pendingPhotos) { photo in
                        Image(uiImage: photo.image).resizable().scaledToFill().frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .topTrailing) {
                                if !model.isSending {
                                    Button { model.removePhoto(photo) } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.6))
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("移除图片")
                                }
                            }
                    }
                }
            }
            .scrollIndicators(.hidden)
            Text(model.photoStatus ?? "已选 \(model.pendingPhotos.count) 张图片")
                .font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("conversation.photo-count")
        }
        .padding(.horizontal, 12).padding(.top, 10)
    }


}
