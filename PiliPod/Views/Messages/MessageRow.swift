import SwiftUI
import UIKit

struct MessageRow: View {
    let row: MessagePresentation
    let emotionURLs: [String: String]
    let heroNamespace: Namespace.ID
    let onImage: (PrivateMessageImagePayload) -> Void
    let onVideo: (VideoItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let timestamp = row.timestamp { MessageTimestampView(date: timestamp) }
            if case .notice(let text) = row.content {
                Text(text).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            } else {
                HStack(spacing: 0) {
                    if row.isMine { Spacer(minLength: 0) }
                    content.containerRelativeFrame(.horizontal, count: 100, span: 74, spacing: 0,
                        alignment: row.isMine ? .trailing : .leading)
                    if !row.isMine { Spacer(minLength: 0) }
                }
                .contextMenu {
                    if let text = row.content.copyText {
                        Button("复制", systemImage: "doc.on.doc") { UIPasteboard.general.string = text }
                    }
                }
                .padding(.top, row.position.startsGroup ? 8 : 3)
                if let delivery = row.delivery { MessageDeliveryStatusView(state: delivery) }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch row.content {
        case .text(let text):
            MessageBubble(text: text, emotionURLs: emotionURLs, isMine: row.isMine, position: row.position)
        case .image(let payload):
            PrivateMessageImageBubble(payload: payload, isMine: row.isMine) { onImage(payload) }
        case .card(let card):
            BiliMessageCard(card: card, heroNamespace: heroNamespace,
                onVideoTap: { if let video = card.videoItem { onVideo(video) } },
                isMine: row.isMine, isEmbedded: card.isUserVideoShare)
        case .unsupported(let text):
            Label(text, systemImage: "questionmark.bubble").font(.callout).foregroundStyle(.secondary)
                .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        case .notice: EmptyView()
        }
    }
}
