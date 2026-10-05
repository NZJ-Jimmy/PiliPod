#if DEBUG
import Foundation

@MainActor
enum DynamicFeedUITestFixture {
    static func makeModel() -> DynamicViewModel {
        var refreshCount = 0
        return DynamicViewModel(loadAuthors: {
            [DynamicFeedAuthor(mid: 42, uname: "测试 UP", face: nil, hasUpdate: true)]
        }, loadPage: { _, _ in
            refreshCount += 1
            let count = refreshCount
            try await Task.sleep(for: .milliseconds(300))
            let items = try (0..<16).map { index in
                let json: String
                if index == 1 {
                    json = """
                    {"id_str":"fixture1","type":"DYNAMIC_TYPE_ARTICLE","modules":{
                    "module_author":{"mid":42,"name":"测试 UP","pub_time":"刚刚"},
                    "module_dynamic":{"major":{"article":{"id":1,"title":"测试专栏 · 刷新\(count)",
                    "desc":"专栏预览","jump_url":"https://example.invalid/article"}}}
                    }}
                    """
                } else if index == 2 {
                    json = """
                    {"id_str":"fixture2","type":"DYNAMIC_TYPE_WORD","modules":{
                    "module_author":{"mid":42,"name":"测试 UP","pub_time":"刚刚"},
                    "module_dynamic":{"desc":{"text":"测试文字动态 · 刷新\(count)"}}
                    }}
                    """
                } else {
                    json = """
                {"id_str":"fixture\(index)","type":"DYNAMIC_TYPE_AV","modules":{
                "module_author":{"mid":42,"name":"测试 UP","pub_time":"刚刚"},
                "module_dynamic":{"major":{"archive":{"bvid":"BV1zz411zzzz","aid":1,
                "title":"测试视频 \(index) · 刷新\(count)","duration_text":"00:30","stat":{"play":10,"danmaku":0}}}}
                }}
                """
                }
                let raw = try JSONDecoder().decode(SpaceDynamicJSONValue.self, from: Data(json.utf8))
                guard let item = UserSpaceDynamicItem.make(from: raw) else { throw URLError(.cannotParseResponse) }
                return item
            }
            return UserSpaceDynamicPageResult(items: items, hasMore: false, nextOffset: nil)
        })
    }
}
#endif
