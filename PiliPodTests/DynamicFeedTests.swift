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

    @Test func authorAndCategoryContinuePastNonMatchingPages() async throws {
        let text = try item("text", type: "DYNAMIC_TYPE_WORD")
        let video = try item("video")
        var offsets: [String?] = []
        let model = DynamicViewModel { filter, offset in
            #expect(filter.authorMID == 42)
            #expect(filter.category == .video)
            offsets.append(offset)
            return offset == nil
                ? UserSpaceDynamicPageResult(items: [text], hasMore: true, nextOffset: "page2")
                : UserSpaceDynamicPageResult(items: [video, video], hasMore: false, nextOffset: nil)
        }
        model.selectedAuthor = DynamicFeedAuthor(mid: 42, uname: "测试 UP", face: nil, hasUpdate: nil)
        model.category = .video
        await model.refresh()
        #expect(offsets.count == 2)
        #expect(offsets[0] == nil)
        #expect(offsets[1] == "page2")
        #expect(model.items.map(\.id) == ["video"])
        #expect(!model.hasMore)
    }

    @Test func sparseFeedAutomaticallyContinuesBeyondFivePages() async throws {
        let text = try item("text", type: "DYNAMIC_TYPE_WORD")
        let video = try item("video")
        var calls = 0
        let model = DynamicViewModel { _, _ in
            calls += 1
            return UserSpaceDynamicPageResult(items: calls == 7 ? [video] : [text], hasMore: calls < 7, nextOffset: String(calls))
        }
        model.selectedAuthor = DynamicFeedAuthor(mid: 42, uname: "测试 UP", face: nil, hasUpdate: nil)
        model.category = .video
        await model.refresh()
        #expect(calls == 7)
        #expect(model.items.map(\.id) == ["video"])
        #expect(!model.hasMore)
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
