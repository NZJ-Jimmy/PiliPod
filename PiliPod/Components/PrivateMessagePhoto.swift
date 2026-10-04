import SwiftUI
import UIKit
import ImageIO

struct PrivateMessagePhoto: Identifiable {
    let id = UUID()
    let data: Data
    var image: UIImage { UIImage(data: data) ?? UIImage() }

    static func prepare(_ data: Data) throws -> PrivateMessagePhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else {
            throw APIError.businessError(code: -400, message: "无法读取这张图片，请重新选择")
        }
        let image = UIImage(cgImage: thumbnail)
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
            throw APIError.businessError(code: -400, message: "图片转换失败")
        }
        return PrivateMessagePhoto(data: jpeg)
    }
}

struct PrivateMessageImageBubble: View {
    let payload: PrivateMessageImagePayload
    let isMine: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 44) }
            Button(action: onOpen) {
                CachedAsyncImage(url: URL(string: payload.url.replacingOccurrences(of: "http://", with: "https://"))) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: Label("图片加载失败", systemImage: "photo").foregroundStyle(.secondary)
                    default: ProgressView()
                    }
                }
                .frame(width: min(240, 300 * CGFloat(max(1, payload.width)) / CGFloat(max(1, payload.height))),
                       height: min(300, 240 * CGFloat(max(1, payload.height)) / CGFloat(max(1, payload.width))))
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看图片")
            if !isMine { Spacer(minLength: 44) }
        }
    }
}
