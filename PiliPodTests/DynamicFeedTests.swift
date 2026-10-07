import Foundation
import Testing
@testable import PiliPod

@MainActor
struct DynamicFeedTests {
    private func item(_ id: String, type: String = "DYNAMIC_TYPE_AV") throws -> UserSpaceDynamicItem {
        let raw = try JSONDecoder().decode(SpaceDynamicJSONValue.self, from: Data("""
        {"id_str":"\(id)","type":"\(type)","modules":{"module_author":{"mid":42,"name":"测试 UP"}}}
        """.utf8))
        return try #require(UserSpaceDynamicItem.make(from: raw))
    }

    @Test func authorAndCategoryLoadsOneServerFilteredPage() async throws {
        let video = try item("video")
        var calls = 0
        let model = DynamicViewModel { filter, offset in
            #expect(filter.authorMID == 42)
            #expect(filter.category == .video)
            #expect(offset == nil)
            calls += 1
            return UserSpaceDynamicPageResult(items: [video, video], hasMore: false, nextOffset: nil)
        }
        model.selectedAuthor = DynamicFeedAuthor(mid: 42, uname: "测试 UP", face: nil, hasUpdate: nil)
        model.category = .video
        await model.refresh()
        #expect(calls == 1)
        #expect(model.items.map(\.id) == ["video"])
        #expect(!model.hasMore)
    }

    @Test func emptyFilteredPageStopsAndResumesFromCursorManually() async throws {
        let video = try item("video")
        var calls = 0
        var offsets: [String?] = []
        let model = DynamicViewModel { _, offset in
            calls += 1
            offsets.append(offset)
            return UserSpaceDynamicPageResult(items: calls == 3 ? [video] : [], hasMore: calls < 3, nextOffset: String(calls))
        }
        model.selectedAuthor = DynamicFeedAuthor(mid: 42, uname: "测试 UP", face: nil, hasUpdate: nil)
        model.category = .video
        await model.refresh()
        #expect(calls == 1)
        #expect(model.items.isEmpty)
        #expect(model.hasMore)
        #expect(model.needsManualContinuation)
        await model.loadIfNeeded()
        #expect(calls == 1)
        await model.loadMore()
        #expect(calls == 2)
        #expect(offsets[1] == "1")
        #expect(model.needsManualContinuation)
        await model.loadMore()
        #expect(calls == 3)
        #expect(offsets[2] == "2")
        #expect(model.items.map(\.id) == ["video"])
        #expect(!model.hasMore)
        #expect(!model.needsManualContinuation)
    }
    @Test func filteredArticlePageDoesNotScanHistory() async throws {
        var calls = 0
        let model = DynamicViewModel { filter, _ in
            #expect(filter.category == .article)
            calls += 1
            return UserSpaceDynamicPageResult(items: [], hasMore: true, nextOffset: "next")
        }
        model.selectedAuthor = DynamicFeedAuthor(mid: 42, uname: "测试 UP", face: nil, hasUpdate: nil)
        model.category = .article
        await model.refresh()
        #expect(calls == 1)
        #expect(model.needsManualContinuation)
    }

    @Test func requestRoutesSendBothServerFilters() throws {
        func query(_ filter: DynamicFeedFilter) throws -> [String: String] {
            let components = try #require(URLComponents(url: filter.requestURL(offset: "next cursor"), resolvingAgainstBaseURL: false))
            return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        }
        let article = DynamicFeedFilter(category: .article, authorMID: 42)
        #expect(article.requestURL().path.hasSuffix("/opus/feed/space"))
        #expect(try query(article)["type"] == "article")
        #expect(try query(article)["host_mid"] == "42")
        #expect(try query(article)["offset"] == "next cursor")
        for category in DynamicCategory.allCases {
            let allAuthors = DynamicFeedFilter(category: category)
            #expect(try query(allAuthors)["type"] == category.apiType)
            #expect(try query(allAuthors)["host_mid"] == nil)
        }
        let video = DynamicFeedFilter(category: .video, authorMID: 42)
        #expect(video.requestURL().path.hasSuffix("/feed/all"))
        #expect(try query(video)["host_mid"] == "42")
        #expect(try query(video)["type"] == "video")
        let pgc = DynamicFeedFilter(category: .pgc, authorMID: 42)
        #expect(try query(pgc)["host_mid"] == "42")
        #expect(try query(pgc)["type"] == "pgc")
    }

    @Test func opusArticleSummaryUsesSelectedAuthorWithoutDetailRequests() throws {
        let raw = try JSONDecoder().decode(SpaceDynamicJSONValue.self, from: Data("""
        {"opus_id":"1234567890123456789","content":"专栏标题","jump_url":"//www.bilibili.com/opus/1234567890123456789",
        "author":null,"cover":{"url":"//i0.hdslb.com/article.jpg"},"stat":{"like":"5"},"pub_time":""}
        """.utf8))
        let author = DynamicFeedAuthor(mid: 42, uname: "测试 UP", face: "https://i0.hdslb.com/face.jpg", hasUpdate: nil)
        let article = try #require(UserSpaceDynamicItem.makeArticle(from: raw, author: author, mid: 42))
        #expect(article.id == "1234567890123456789")
        #expect(article.author.name == "测试 UP")
        #expect(article.author.mid == 42)
        #expect(article.previewCard?.link == "https://www.bilibili.com/opus/1234567890123456789")
        #expect(article.previewCard?.title == "专栏标题")
        #expect(article.statistics.like == 5)
        #expect(article.commentTarget.resourceID == nil)
    }

    @Test func riskControlFailureStopsAutomaticRetryAndRetainsExistingFeed() async throws {
        let first = try item("first")
        var calls = 0
        let model = DynamicViewModel { _, _ in
            calls += 1
            if calls > 1 { throw APIError.businessError(code: -352, message: "-352") }
            return UserSpaceDynamicPageResult(items: [first], hasMore: true, nextOffset: "next")
        }
        await model.refresh()
        await model.loadMore()
        #expect(model.items.map(\.id) == ["first"])
        #expect(model.errorMessage?.contains("风控") == true)
        await model.loadMoreIfNeeded(current: first)
        await model.loadIfNeeded()
        #expect(calls == 2)
        #expect(APIError.responseError(412).localizedDescription.contains("HTTP 412"))
    }

    @Test func returningToLoadedFilterKeepsItemsAndPaginationCursor() async throws {
        let first = try item("first")
        let second = try item("second")
        var offsets: [String?] = []
        let model = DynamicViewModel { _, offset in
            offsets.append(offset)
            return offset == nil
                ? UserSpaceDynamicPageResult(items: [first], hasMore: true, nextOffset: "next")
                : UserSpaceDynamicPageResult(items: [second], hasMore: false, nextOffset: nil)
        }
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        #expect(offsets.count == 1)
        #expect(model.items.map(\.id) == ["first"])
        await model.loadMore()
        #expect(offsets.count == 2)
        #expect(offsets[1] == "next")
        #expect(model.items.map(\.id) == ["first", "second"])
    }

    @Test func cancelledRefreshRetainsCardsAndCursor() async throws {
        let first = try item("first")
        let second = try item("second")
        var calls = 0
        let model = DynamicViewModel { _, offset in
            calls += 1
            if calls == 2 { throw CancellationError() }
            return offset == nil
                ? UserSpaceDynamicPageResult(items: [first], hasMore: true, nextOffset: "next")
                : UserSpaceDynamicPageResult(items: [second], hasMore: false, nextOffset: nil)
        }
        await model.refresh()
        await model.refresh()
        #expect(model.items.map(\.id) == ["first"])
        #expect(model.errorMessage == nil)
        #expect(model.hasMore)
        await model.loadIfNeeded()
        #expect(calls == 2)
        await model.loadMore()
        #expect(model.items.map(\.id) == ["first", "second"])
    }

    @Test func refreshKeepsCardsVisibleUntilReplacementArrives() async throws {
        let first = try item("first")
        let replacement = try item("replacement")
        let loader = SuspendedDynamicLoader()
        var calls = 0
        let model = DynamicViewModel { filter, _ in
            calls += 1
            if calls == 1 { return UserSpaceDynamicPageResult(items: [first], hasMore: false, nextOffset: nil) }
            return await loader.load(filter.category)
        }
        await model.refresh()
        let refreshTask = Task { await model.refresh() }
        for _ in 0..<1000 {
            if loader.pending[.all] != nil { break }
            await Task.yield()
        }
        let continuation = try #require(loader.pending[.all])
        #expect(model.isLoading)
        #expect(model.items.map(\.id) == ["first"])
        continuation.resume(returning: UserSpaceDynamicPageResult(items: [replacement], hasMore: false, nextOffset: nil))
        await refreshTask.value
        #expect(model.items.map(\.id) == ["replacement"])
    }

    @Test func paginationErrorPreservesItemsAndRetriesSameCursor() async throws {
        let first = try item("first")
        let second = try item("second")
        var failed = false
        let model = DynamicViewModel { _, offset in
            if offset == nil {
                return UserSpaceDynamicPageResult(items: [first], hasMore: true, nextOffset: "next")
            }
            #expect(offset == "next")
            if !failed { failed = true; throw URLError(.timedOut) }
            return UserSpaceDynamicPageResult(items: [first, second], hasMore: false, nextOffset: nil)
        }
        await model.refresh()
        await model.loadMore()
        #expect(model.items.map(\.id) == ["first"])
        #expect(model.errorMessage != nil)
        #expect(model.hasMore)
        await model.loadMore()
        #expect(model.items.map(\.id) == ["first", "second"])
        #expect(model.errorMessage == nil)
    }

    @Test func repeatedCursorStopsPagination() async throws {
        let first = try item("first")
        let model = DynamicViewModel { _, _ in
            UserSpaceDynamicPageResult(items: [first], hasMore: true, nextOffset: "same")
        }
        await model.refresh()
        await model.loadMore()
        #expect(!model.hasMore)
        #expect(model.items.count == 1)
    }

    @Test func lateResponseCannotOverwriteNewFilter() async throws {
        let old = try item("old")
        let new = try item("new")
        let loader = SuspendedDynamicLoader()
        let model = DynamicViewModel { filter, _ in await loader.load(filter.category) }
        let oldTask = Task { await model.refresh() }
        for _ in 0..<1000 {
            if loader.pending[.all] != nil { break }
            await Task.yield()
        }
        let oldContinuation = try #require(loader.pending[.all])
        model.category = .video
        let newTask = Task { await model.refresh() }
        for _ in 0..<1000 {
            if loader.pending[.video] != nil { break }
            await Task.yield()
        }
        let newContinuation = try #require(loader.pending[.video])
        newContinuation.resume(returning: UserSpaceDynamicPageResult(items: [new], hasMore: false, nextOffset: nil))
        await newTask.value
        oldContinuation.resume(returning: UserSpaceDynamicPageResult(items: [old], hasMore: true, nextOffset: "old"))
        await oldTask.value
        #expect(model.items.map(\.id) == ["new"])
        #expect(!model.hasMore)
        #expect(!model.isLoading)
    }

    @Test func repostIsNotAnOriginalSubmission() throws {
        #expect(!DynamicCategory.video.matches(try item("forward", type: "DYNAMIC_TYPE_FORWARD")))
        #expect(DynamicCategory.pgc.matches(try item("pgc", type: "DYNAMIC_TYPE_PGC_UNION")))
        #expect(DynamicCategory.article.matches(try item("article", type: "DYNAMIC_TYPE_ARTICLE")))
    }
}

@MainActor
private final class SuspendedDynamicLoader {
    var pending: [DynamicCategory: CheckedContinuation<UserSpaceDynamicPageResult, Never>] = [:]

    func load(_ category: DynamicCategory) async -> UserSpaceDynamicPageResult {
        await withCheckedContinuation { pending[category] = $0 }
    }
}
