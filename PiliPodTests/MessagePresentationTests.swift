import Foundation
import Testing
@testable import PiliPod

struct MessagePresentationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func message(_ key: UInt64, sender: UInt64 = 1, time: UInt64 = 1_700_000_000) -> Bilibili_Im_Type_Msg {
        var message = Bilibili_Im_Type_Msg()
        message.msgKey = key
        message.msgSeqno = key
        message.senderUid = sender
        message.timestamp = time
        message.msgType = .enMsgTypeText
        message.content = "{\"content\":\"你好 😀\"}"
        return message
    }
    private func layout(_ messages: [Bilibili_Im_Type_Msg]) -> [MessagePresentation] {
        MessagePresentationAdapter.layout(messages.map {
            MessagePresentation(id: MessagePresentationAdapter.identity($0), message: $0,
                content: MessagePresentationAdapter.content($0), isMine: $0.senderUid == 1)
        }, calendar: calendar)
    }

    @Test func singleHasTailAndTimestamp() {
        let rows = layout([message(1)])
        #expect(rows[0].position == .single)
        #expect(rows[0].position.hasTail)
        #expect(rows[0].timestamp != nil)
    }
    @Test func consecutiveMessagesHaveOnlyOneTail() {
        let two = layout([message(1), message(2, time: 1_700_000_001)])
        #expect(two.map(\.position) == [.first, .last])
        let three = layout([message(1), message(2), message(3)])
        #expect(three.map(\.position) == [.first, .middle, .last])
        #expect(!three[1].position.hasTail)
    }
    @Test func senderChangesBreakGroups() {
        let rows = layout([message(1), message(2, sender: 2), message(3)])
        #expect(rows.allSatisfy { $0.position == .single })
    }
    @Test func groupingIncludesExactThresholdButNotBeyond() {
        let rows = layout([message(1), message(2, time: 1_700_000_300), message(3, time: 1_700_000_601)])
        #expect(rows.map(\.position) == [.first, .last, .single])
    }
    @Test func timeSeparatorUsesFifteenMinuteGap() {
        let rows = layout([message(1), message(2, time: 1_700_000_900), message(3, time: 1_700_001_801)])
        #expect(rows[0].timestamp != nil)
        #expect(rows[1].timestamp == nil)
        #expect(rows[2].timestamp != nil)
    }
    @Test func midnightAndSystemMessageBreakGroups() {
        let midnight: UInt64 = 1_699_920_000 // UTC midnight
        let crossDay = layout([message(1, time: midnight - 1), message(2, time: midnight + 1)])
        #expect(crossDay.map(\.position) == [.single, .single])
        #expect(crossDay[1].timestamp != nil)
        var notice = message(2)
        notice.sysCancel = true
        let rows = layout([message(1), notice, message(3)])
        #expect(rows.allSatisfy { $0.position == .single })
        #expect(rows[1].content.isSystem)
    }
    @Test func missingOrBackwardsTimeDoesNotInventDateOrGroup() {
        let rows = layout([message(1, time: 0), message(2), message(3, time: 1_699_999_999)])
        #expect(rows[0].timestamp == nil)
        #expect(rows.allSatisfy { $0.position == .single })
    }
    @Test func contentMappingPreservesTextImagesCardsAndUnknownTypes() throws {
        let text = message(1)
        #expect(MessagePresentationAdapter.content(text).copyText == "你好 😀")
        var image = message(2)
        image.msgType = .enMsgTypePic
        image.content = "{\"url\":\"https://i0.hdslb.com/test.jpg\",\"width\":640,\"height\":480}"
        if case .image(let payload) = MessagePresentationAdapter.content(image) {
            #expect(payload.width == 640)
            #expect(payload.height == 480)
        } else { Issue.record("Expected image presentation") }
        var card = message(3)
        card.msgType = .enMsgTypeVideoCard
        card.content = "{\"title\":\"视频\",\"bvid\":\"BV123\",\"cover\":\"https://i0.hdslb.com/video.jpg\"}"
        if case .card(let payload) = MessagePresentationAdapter.content(card) {
            #expect(payload.title == "视频")
            #expect(payload.bvid == "BV123")
        } else { Issue.record("Expected video card presentation") }
        var unsupported = message(4)
        unsupported.msgType = .enMsgTypeAudio
        if case .unsupported = MessagePresentationAdapter.content(unsupported) {} else {
            Issue.record("Audio should not display raw JSON as text")
        }
    }
    @Test func mediaCanGroupWithoutTextBubbleWrapping() {
        var image = message(2)
        image.msgType = .enMsgTypePic
        image.content = "{\"url\":\"https://i0.hdslb.com/test.jpg\"}"
        let rows = layout([message(1), image, message(3)])
        #expect(rows.map(\.position) == [.first, .middle, .last])
    }
    @MainActor @Test func acknowledgementAndRefreshKeepOneStableLocalIdentity() {
        let model = ConversationViewModel(session: PrivateMessageSession(session: Bilibili_Im_Type_SessionInfo()))
        model.beginPendingText("你好 😀")
        let localID = model.rows[0].id
        #expect(model.rows[0].delivery == .sending)
        let acknowledged = message(5, sender: model.currentMID)
        model.appendSentMessage(PrivateMessageSendResult(message: acknowledged, emotions: []))
        #expect(model.rows.count == 1)
        #expect(model.rows[0].id == localID)
        #expect(model.rows[0].delivery == .sent)
        model.merge([acknowledged, acknowledged])
        #expect(model.rows.count == 1)
        #expect(model.rows[0].id == localID)
    }
    @MainActor @Test func prependingHistoryPreservesExistingIdentitiesAndDeduplicatesBoundary() {
        let model = ConversationViewModel(session: PrivateMessageSession(session: Bilibili_Im_Type_SessionInfo()))
        model.merge([message(3), message(4)])
        let existing = model.rows.map(\.id)
        model.merge([message(1), message(2), message(3)])
        #expect(model.rows.map { $0.message.msgSeqno } == [1, 2, 3, 4])
        #expect(Array(model.rows.suffix(2).map(\.id)) == existing)
        #expect(model.rows.allSatisfy { $0.delivery == nil })
    }
}
