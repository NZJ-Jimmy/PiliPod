import XCTest

final class ConversationUITests: XCTestCase {
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
        XCTAssertTrue(latest.isHittable, "Opening the keyboard must keep the latest message visible")
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

        app.buttons["选择照片"].tap()
        XCTAssertFalse(app.staticTexts["照片"].exists, "The photo panel must have no extra title bar")
        // The native picker runs in a remote view service and shows onboarding on first use.
        let onboarding = app.buttons["OK"]
        if onboarding.waitForExistence(timeout: 10) { onboarding.tap() }
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 25), "Native photo thumbnails should load")
        photo.tap()
        XCTAssertTrue(app.staticTexts["conversation.photo-count"].waitForExistence(timeout: 15), "Selecting a photo must immediately add it to the composer")
        XCTAssertTrue(panel.exists, "Continuous selection must keep the picker open")
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
}
