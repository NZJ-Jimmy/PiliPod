import SwiftUI
import UIKit

private struct MessageCardCoverView: View {
    let url: URL?

    #if canImport(UIKit)
    @State private var image: UIImage?
    #endif
    @State private var didFail = false

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if didFail || url == nil {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
            #else
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        #if canImport(UIKit)
        image = nil
        #endif
        didFail = false

        guard let url else {
            print("[MessageCardCover] invalid URL")
            didFail = true
            return
        }

        #if canImport(UIKit)
        guard let loadedImage = await SharedRemoteImageStore.shared.image(for: url) else {
            print("[MessageCardCover] load failed: \(url.absoluteString)")
            didFail = true
            return
        }
        image = loadedImage
        #else
        didFail = true
        #endif
    }
}

struct BiliMessageCard: View {
    let card: MessageCardPayload
    let heroNamespace: Namespace.ID
    let onVideoTap: () -> Void
    let isMine: Bool
    let isEmbedded: Bool

    var body: some View {
        Button(action: onVideoTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    ZStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.14))
                        MessageCardCoverView(url: MessagePayload.url(from: card.coverURL))
                    }
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    if card.kind == .video, card.duration > 0 {
                        Text(Self.durationText(card.duration))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .glassEffect(.regular, in: Capsule())
                            .padding(8)
                    }
                }

                Text(card.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, card.summary.isEmpty ? 12 : 4)

                if !card.summary.isEmpty {
                    Text(card.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
            }
            .background(
                AnyShapeStyle(.regularMaterial),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 292)
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
        .matchedTransitionSource(id: "conversationVideo.\(card.bvid ?? card.title)", in: heroNamespace)
        .disabled(card.videoItem == nil)
        .opacity(card.videoItem == nil ? 0.9 : 1)
    }

    private static func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return minutes >= 60
            ? String(format: "%d:%02d:%02d", minutes / 60, minutes % 60, remaining)
            : String(format: "%02d:%02d", minutes, remaining)
    }
}
