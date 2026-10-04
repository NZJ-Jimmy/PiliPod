import Foundation
import Testing
@testable import PiliPod

struct LibraryTests {
    @Test func subscriptionsDecodeBothFolderAndCollection() throws {
        let json = #"{"code":0,"data":{"has_more":true,"list":[{"id":1,"title":"收藏夹","type":11,"media_count":25},{"id":2,"title":"合集","type":21,"state":1}]}}"#
        let response = try JSONDecoder().decode(LibraryEnvelope<LibraryFolderData>.self, from: Data(json.utf8))
        let folders = try #require(response.data?.list)
        #expect(response.data?.hasMore == true)
        #expect(!folders[0].isCollection)
        #expect(folders[1].isCollection)
        #expect(folders[1].isUnavailable)
    }

    @Test func legacyVideoIDsAndMissingMetadataDecode() throws {
        let json = #"{"id":123,"bv_id":"BV1test","cover":"http://example.com/cover.jpg","type":2,"cnt_info":{"play":100}}"#
        let media = try JSONDecoder().decode(LibraryMedia.self, from: Data(json.utf8))
        let video = try #require(media.video)
        #expect(video.bvid == "BV1test")
        #expect(video.cover == "https://example.com/cover.jpg")
        #expect(video.duration == 0)
        #expect(video.uploader.isEmpty)
    }

    @Test func invalidAndNonVideoResourcesCannotOpenPlayer() throws {
        for json in [
            #"{"id":1,"bvid":"BV1test","attr":9,"type":2}"#,
            #"{"id":2,"bvid":"BV1test","type":12}"#,
            #"{"id":3,"type":2}"#
        ] {
            let media = try JSONDecoder().decode(LibraryMedia.self, from: Data(json.utf8))
            #expect(media.video == nil)
        }
    }

    @Test func unavailableVideoRetainsDisplayMetadata() throws {
        let json = #"{"id":101,"title":"已失效视频","type":2,"attr":9,"duration":373,"upper":{"name":"epcdiy"},"cnt_info":{"play":97000,"danmaku":560}}"#
        let media = try JSONDecoder().decode(LibraryMedia.self, from: Data(json.utf8))
        #expect(media.video == nil)
        #expect(media.displayVideo.title == "已失效视频")
        #expect(media.displayVideo.durationFormatted == "06:13")
        #expect(media.displayVideo.uploader == "epcdiy")
        #expect(media.displayVideo.playCount != "--")
        #expect(media.displayVideo.danmakuCount == "560")
    }

    @Test @MainActor func failedPaginationRetriesSamePageAndKeepsExistingItems() async {
        var requestedPages: [Int] = []
        var failedOnce = false
        let model = LibraryViewModel<TestEntry> { page in
            requestedPages.append(page)
            if page == 1 { return LibraryPage(entries: [TestEntry(id: 1)], hasMore: true) }
            if !failedOnce {
                failedOnce = true
                throw URLError(.notConnectedToInternet)
            }
            return LibraryPage(entries: [TestEntry(id: 1), TestEntry(id: 2)], hasMore: false)
        }
        await model.loadMore()
        await model.loadMore()
        #expect(model.entries.map(\.id) == [1])
        #expect(model.errorMessage != nil)
        await model.loadMore()
        #expect(requestedPages == [1, 2, 2])
        #expect(model.entries.map(\.id) == [1, 2])
        #expect(!model.hasMore)
        #expect(model.errorMessage == nil)
    }

    @Test @MainActor func accountResetDiscardsInFlightResponse() async {
        var continuation: CheckedContinuation<LibraryPage<TestEntry>, Error>?
        let model = LibraryViewModel<TestEntry> { _ in
            try await withCheckedThrowingContinuation { continuation = $0 }
        }
        let request = Task { await model.loadMore() }
        while continuation == nil { await Task.yield() }
        model.reset()
        continuation?.resume(returning: LibraryPage(entries: [TestEntry(id: 1)], hasMore: false))
        await request.value
        #expect(model.entries.isEmpty)
        #expect(!model.isLoading)
        #expect(model.hasMore)
    }

    private struct TestEntry: Identifiable { let id: Int }
}
