import Foundation
import Testing
@testable import PiliPod

struct SwiftChatMediaDataTests {
    @Test func readsSDKInlineImage() async throws {
        let expected = Data([0, 1, 2, 255])
        let url = try #require(URL(string: "data:image/jpeg;base64," + expected.base64EncodedString()))
        #expect(try await SwiftChatMediaData.read(url) == expected)
    }
    @Test func rejectsMalformedInlineImage() async {
        do {
            _ = try await SwiftChatMediaData.read(URL(string: "data:image/jpeg;base64,???")!)
            Issue.record("Malformed media must not upload")
        } catch {}
    }
    @Test func readsSDKLocalImage() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        let expected = Data([1, 2, 3])
        try expected.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try await SwiftChatMediaData.read(url) == expected)
    }
}
