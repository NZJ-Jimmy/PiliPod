#if DEBUG
import SwiftUI
import UIKit

// Exercise the production views with loaded images without Bilibili credentials.
struct LibraryLayoutFixtureView: View {
    init() {
        Self.cacheCover(name: "wide", size: CGSize(width: 1600, height: 500), color: .systemTeal)
        Self.cacheCover(name: "tall", size: CGSize(width: 500, height: 1600), color: .systemOrange)
    }

    var body: some View {
        NavigationStack {
            LibraryFoldersView(subscriptions: false, requiresLogin: false, loader: { _ in
                let data = Data(#"{"list":[{"id":1,"title":"横向大尺寸封面收藏夹","cover":"https://library-test.invalid/wide","media_count":3},{"id":2,"title":"竖向大尺寸封面收藏夹","cover":"https://library-test.invalid/tall","media_count":3},{"id":3,"title":"很长的收藏夹标题，用来检查双列标题与下一行封面是否重叠","cover":"https://library-test.invalid/wide","media_count":3},{"id":4,"title":"无封面收藏夹","media_count":3}]}"#.utf8)
                let folders = try JSONDecoder().decode(LibraryFolderData.self, from: data)
                return LibraryPage(entries: folders.list ?? [], hasMore: false)
            }, mediaLoader: { _, _ in
                let data = Data(#"{"medias":[{"id":101,"title":"已失效视频","type":2,"attr":9,"duration":373,"upper":{"name":"epcdiy"},"pubtime":1708387200,"cnt_info":{"play":97000,"danmaku":560}},{"id":102,"title":"正常视频使用相同的封面和信息布局","bvid":"BV1fixture","type":2,"cover":"https://library-test.invalid/wide","duration":373,"upper":{"name":"测试UP主"},"pubtime":1708387200,"cnt_info":{"play":97000,"danmaku":560}},{"id":103,"title":"已失效的长标题视频，同样保留完整行高，不能遮挡下一行的视频卡片","type":2,"attr":9,"duration":100}]}"#.utf8)
                let media = try JSONDecoder().decode(LibraryMediaData.self, from: data)
                return LibraryPage(entries: media.medias ?? [], hasMore: false)
            })
        }
        .preferredColorScheme(.dark)
    }

    private static func cacheCover(name: String, size: CGSize, color: UIColor) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.withAlphaComponent(0.4).setFill()
            context.fill(CGRect(x: size.width * 0.3, y: 0, width: size.width * 0.4, height: size.height))
        }
        guard let url = URL(string: "https://library-test.invalid/" + name),
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                             headerFields: ["Content-Type": "image/png"]),
              let data = image.pngData() else { return }
        URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: URLRequest(url: url))
    }
}
#endif
