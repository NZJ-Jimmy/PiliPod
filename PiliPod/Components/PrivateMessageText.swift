import SwiftUI
import UIKit

/// Text attachments share the same wrapping and baseline as the surrounding message.
struct PrivateMessageText: View {
    let text: String
    let emotionURLs: [String: String]
    @State private var images: [String: UIImage] = [:]
    @ScaledMetric(relativeTo: .body) private var emoteHeight: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var emoteBaseline: CGFloat = -3

    private var matchingURLs: [String: String] {
        emotionURLs.filter { !$0.key.isEmpty && text.contains($0.key) }
    }

    var body: some View {
        renderedText
            .task(id: matchingURLs.sorted { $0.key < $1.key }.map { $0.key + $0.value }.joined() + String(describing: emoteHeight)) {
                var loaded: [String: UIImage] = [:]
                for (token, raw) in matchingURLs {
                    let normalized = raw.hasPrefix("//") ? "https:" + raw : raw.replacingOccurrences(of: "http://", with: "https://")
                    guard let url = URL(string: normalized),
                          let source = await SharedRemoteImageStore.shared.image(for: url) else { continue }
                    guard !Task.isCancelled else { return }
                    let height = emoteHeight
                    let width = height * source.size.width / max(1, source.size.height)
                    loaded[token] = UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { _ in
                        source.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
                    }
                }
                guard !Task.isCancelled else { return }
                images = loaded
            }
            .accessibilityLabel(text)
    }

    private var renderedText: Text {
        let tokens = images.keys.sorted { $0.count > $1.count }
        var result = Text("")
        var remaining = text[...]
        var plain = ""
        while !remaining.isEmpty {
            if let token = tokens.first(where: { remaining.hasPrefix($0) }), let image = images[token] {
                result = result + Text(plain) + Text(Image(uiImage: image)).baselineOffset(emoteBaseline)
                plain = ""
                remaining = remaining.dropFirst(token.count)
            } else {
                plain.append(remaining.removeFirst())
            }
        }
        return result + Text(plain)
    }
}
