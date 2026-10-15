import XCTest

final class ConversationUITests: XCTestCase {
    @MainActor
    func testBottomFollowingAfterReturningFromHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-conversation"]
        app.launch()
        let messages = app.scrollViews["conversation.messages"]
        XCTAssertTrue(messages.waitForExistence(timeout: 15))
        let latest = app.staticTexts["多行输入和面板布局测试"]
        for _ in 0..<4 { messages.swipeDown() }
        XCTAssertFalse(latest.isHittable, "The test must first leave the bottom")

        let input = app.descendants(matching: .any)["conversation.input"].firstMatch
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(latest.isHittable, "Opening the keyboard while reading history must not jump to latest")
        // Close the keyboard through the existing input-panel controls, then
        // return to bottom with no input surface visible before reopening it.
        app.buttons["选择表情"].tap()
        let historyPanel = app.otherElements["conversation.panel"].firstMatch
        XCTAssertTrue(historyPanel.waitForExistence(timeout: 5))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.keyboards.firstMatch)], timeout: 5), .completed)
        XCTAssertFalse(latest.isHittable, "Opening a panel while reading history must not jump to latest")
        let historyHandle = historyPanel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03))
        historyHandle.press(forDuration: 0.1,
            thenDragTo: historyHandle.withOffset(CGVector(dx: 0, dy: 260)))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "exists == false"),
            evaluatedWith: historyPanel)], timeout: 5), .completed)
        for _ in 0..<8 { messages.swipeUp() }
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        assertLatestVisible(latest, in: messages)
        capture(app, "conversation-bottom-again-keyboard")

        app.buttons["选择表情"].tap()
        let panel = app.otherElements["conversation.panel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        assertLatestVisible(latest, in: messages)
        capture(app, "conversation-bottom-again-panel")
        let handle = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03))
        handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: 0, dy: -180)))
        assertLatestVisible(latest, in: messages)
        capture(app, "conversation-bottom-again-expanded-panel")
    }

    @MainActor
    func testSendDuringHistoryLoadKeepsLatestVisible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-conversation", "--uitest-slow-history"]
        app.launch()
        let messages = app.scrollViews["conversation.messages"]
        XCTAssertTrue(messages.waitForExistence(timeout: 15))
        let history = app.buttons["conversation.history"]
        for _ in 0..<8 {
            if history.isHittable { break }
            messages.swipeDown()
        }
        history.tap()
        let input = app.descendants(matching: .any)["conversation.input"].firstMatch
        input.tap()
        input.typeText("Race")
        XCTAssertTrue(history.exists, "The delayed history request must still be in flight")
        app.buttons["conversation.send"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: history)], timeout: 15), .completed)
        let sent = app.staticTexts["Race"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: sent)], timeout: 5), .completed,
            "A late history response must not move away from the user's newly sent message")
        capture(app, "conversation-send-during-history")
    }

    @MainActor
    func testGroupedTimelineAndSystemNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-conversation", "--uitest-groups"]
        app.launch()
        XCTAssertTrue(app.staticTexts["多行输入和面板布局测试"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.isHittable)
        capture(app, "conversation-groups-light")
    }

    @MainActor
    func testHistoryPrependPreservesViewportAndSendReturnsToLatest() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-conversation"]
        app.launch()
        let messages = app.scrollViews["conversation.messages"]
        XCTAssertTrue(messages.waitForExistence(timeout: 15))
        let history = app.buttons["conversation.history"]
        for _ in 0..<8 {
            if history.isHittable { break }
            messages.swipeDown()
        }
        XCTAssertTrue(history.isHittable)
        let anchor = app.staticTexts["历史消息 1"]
        XCTAssertTrue(anchor.isHittable)
        let y = anchor.frame.minY
        capture(app, "conversation-before-history")
        history.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: history)], timeout: 15), .completed)
        XCTAssertTrue(anchor.isHittable)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
            abs(anchor.frame.minY - y) < 6
        }, evaluatedWith: anchor)], timeout: 5), .completed)
        XCTAssertLessThan(abs(anchor.frame.minY - y), 6, "Prepending a page must preserve the visible message's pixel position")
        capture(app, "conversation-after-history")
        let input = app.descendants(matching: .any)["conversation.input"].firstMatch
        input.tap()
        input.typeText("Send from history")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value == %@", "Send from history"),
            evaluatedWith: input)], timeout: 5), .completed)
        app.buttons["conversation.send"].tap()
        let sent = app.staticTexts["Send from history"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: sent)], timeout: 10), .completed)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        capture(app, "conversation-send-from-history")
    }

    @MainActor
    func testNativeCopyMenuAndDarkLargeTextComposer() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-conversation", "--uitest-dark", "--uitest-large-text", "--uitest-groups"]
        app.launch()
        let last = app.staticTexts["多行输入和面板布局测试"]
        XCTAssertTrue(last.waitForExistence(timeout: 15))
        last.press(forDuration: 1)
        XCTAssertTrue(app.buttons["复制"].waitForExistence(timeout: 5))
        capture(app, "conversation-native-copy-dark")
        app.buttons["复制"].tap()
        let input = app.descendants(matching: .any)["conversation.input"].firstMatch
        input.tap()
        input.typeText("Accessible")
        XCTAssertTrue(app.buttons["conversation.send"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["选择照片"].frame.width, 44)
        XCTAssertGreaterThanOrEqual(app.buttons["选择表情"].frame.width, 44)
        capture(app, "conversation-dark-large-text")
    }

    @MainActor
    func testComposerAlignmentAndExpandablePanels() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-conversation"]
        app.launch()
        let input = app.descendants(matching: .any)["conversation.input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        input.typeText("Hello")
        let send = app.buttons["conversation.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        XCTAssertLessThan(abs(send.frame.midY - input.frame.midY), 4, "Send arrow must align with a single-line input")
        XCTAssertLessThan(abs(app.buttons["选择照片"].frame.midY - send.frame.midY), 2)
        XCTAssertLessThan(abs(app.buttons["选择表情"].frame.midY - send.frame.midY), 2)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        let keyboardInputY = input.frame.maxY
        let latest = app.staticTexts["多行输入和面板布局测试"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: latest)], timeout: 5), .completed,
            "Opening the keyboard must keep the latest message visible")
        capture(app, "conversation-keyboard-before-send")
        send.tap()
        XCTAssertTrue(input.isEnabled, "Sending must keep the input enabled to retain keyboard focus")
        let cleared = NSPredicate(format: "value == %@ OR value == %@", "消息", "")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: cleared, evaluatedWith: input)], timeout: 5), .completed)
        XCTAssertTrue(keyboard.exists, "Sending must retain the keyboard")
        XCTAssertLessThan(abs(input.frame.maxY - keyboardInputY), 2)
        input.typeText("Hello")
        capture(app, "conversation-keyboard")

        app.buttons["选择表情"].tap()
        let panel = app.otherElements["conversation.panel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["😀"].waitForExistence(timeout: 5))
        // Accessibility groups can include clipped/offscreen scroll children; compare the visible composer anchor.
        XCTAssertLessThan(abs(input.frame.maxY - keyboardInputY), 16, "Switching keyboard to the panel must preserve the composer position")
        capture(app, "conversation-emotes-collapsed")
        let collapsedHeight = panel.frame.height
        let start = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -180)))
        XCTAssertTrue(panel.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(panel.frame.height, collapsedHeight + 60)
        capture(app, "conversation-emotes-expanded")
        app.buttons["显示键盘"].tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: panel)], timeout: 5), .completed)
        XCTAssertLessThan(abs(input.frame.maxY - keyboardInputY), 4, "Returning from an expanded panel must restore the system keyboard position")
        capture(app, "conversation-keyboard-after-panel")

        app.buttons["选择照片"].tap()
        XCTAssertFalse(app.staticTexts["照片"].exists, "The photo panel must have no extra title bar")
        // The native picker runs in a remote view service and shows onboarding on first use.
        let onboarding = app.buttons["OK"]
        if onboarding.waitForExistence(timeout: 10) { onboarding.tap() }
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 25), "Native photo thumbnails should load")
        // The remote picker can finish loading its grid before presenting onboarding.
        // Dismiss a late prompt as well; its grid remains in the accessibility tree behind it.
        if onboarding.waitForExistence(timeout: 10) {
            onboarding.tap()
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "exists == false"),
                evaluatedWith: onboarding)], timeout: 5), .completed)
        }
        assertThreePhotoColumns(in: app, panel: panel)
        capture(app, "conversation-photos-before-selection")
        let photoCollapsedHeight = panel.frame.height
        let photoHandle = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03))
        photoHandle.press(forDuration: 0.1, thenDragTo: photoHandle.withOffset(CGVector(dx: 0, dy: -180)))
        XCTAssertGreaterThan(panel.frame.height, photoCollapsedHeight + 60)
        assertThreePhotoColumns(in: app, panel: panel)
        capture(app, "conversation-photos-expanded-three-columns")
        let expandedPhotoHandle = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03))
        expandedPhotoHandle.press(forDuration: 0.1,
            thenDragTo: expandedPhotoHandle.withOffset(CGVector(dx: 0, dy: 180)))
        XCTAssertLessThan(abs(panel.frame.height - photoCollapsedHeight), 4)
        assertThreePhotoColumns(in: app, panel: panel)
        // Native grid image accessibility nodes have no hittable point; tap their actual on-screen center.
        // A remote picker can retain accessibility nodes for scrolled-off thumbnails.
        // Choose a center inside both the panel and the app instead of its first node.
        let pickerBounds = panel.frame.intersection(app.frame)
        let visiblePhoto = app.images.matching(identifier: "PXGGridLayout-Info")
            .allElementsBoundByIndex.first { item in
                let frame = item.frame
                return frame.width > 0 && frame.height > 0
                    && frame.midX > pickerBounds.minX && frame.midX < pickerBounds.maxX
                    && frame.midY > pickerBounds.minY + 44 && frame.midY < pickerBounds.maxY - 34
            }
        let thumbnail = try XCTUnwrap(visiblePhoto, "A visible native photo thumbnail is required")
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: thumbnail.frame.midX, dy: thumbnail.frame.midY)).tap()
        // Thumbnail selection is immediate, but the remote picker imports the
        // full asset asynchronously and can take over 15 seconds on a cold CI simulator.
        XCTAssertTrue(app.staticTexts["conversation.photo-count"].waitForExistence(timeout: 30),
            "Selecting a photo must add it to the composer when import completes")
        XCTAssertTrue(panel.exists, "Continuous selection must keep the picker open")
        XCTAssertGreaterThanOrEqual(app.buttons["移除图片"].frame.width, 44)
        XCTAssertFalse(app.buttons["添加 1 张"].exists)
        capture(app, "conversation-photos")
        let messages = app.scrollViews["conversation.messages"]
        let chatDrag = messages.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        chatDrag.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.96)))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: panel)], timeout: 5), .completed,
            "Dragging the conversation into the panel must dismiss it")
        capture(app, "conversation-panel-dismissed")
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor private func assertLatestVisible(_ latest: XCUIElement, in messages: XCUIElement) {
        let result = XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
            latest.isHittable && latest.frame.maxY <= messages.frame.maxY + 1
        }, evaluatedWith: latest)], timeout: 5)
        XCTAssertEqual(result, .completed,
            "Returning to bottom must restore following through keyboard and panel resizing")
    }

    @MainActor private func assertThreePhotoColumns(in app: XCUIApplication, panel: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
            let bounds = panel.frame.intersection(app.frame)
            let widths = app.images.matching(identifier: "PXGGridLayout-Info").allElementsBoundByIndex
                .map(\.frame).filter { $0.intersects(bounds) && $0.width > 0 }.map(\.width)
            return !widths.isEmpty && widths.allSatisfy {
                $0 > bounds.width * 0.28 && $0 < bounds.width * 0.36
            }
        }, evaluatedWith: panel)], timeout: 10), .completed,
            "Collapsed and expanded native photo grids must both use three columns")
    }
}
