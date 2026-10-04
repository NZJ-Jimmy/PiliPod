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
        Button(action: onOpen) {
            CachedAsyncImage(url: MessagePayload.url(from: payload.url)) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit()
                case .failure: Label("图片加载失败", systemImage: "photo").foregroundStyle(.secondary)
                default: ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(CGFloat(max(1, payload.width)) / CGFloat(max(1, payload.height)), contentMode: .fit)
            .frame(maxHeight: 360)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看图片")
    }
}
