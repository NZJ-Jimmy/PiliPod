import XCTest

final class SwiftChatConversationUITests: XCTestCase {
    @MainActor func testNativeComposerSendsAndOpensPhotos() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-conversation"]
        app.launch()
        let input = inputView(app)
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        input.typeText("Swift Chat test")
        let send = app.buttons["chat.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        capture(app, "swiftchat-keyboard")
        send.tap()
        let cleared = NSPredicate { _, _ in !(input.value as? String ?? "").contains("Swift Chat test") }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: cleared, evaluatedWith: input)], timeout: 10), .completed)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        capture(app, "swiftchat-sent")
        app.buttons["chat.attach"].tap()
        XCTAssertTrue(app.buttons["chat.attach.photos"].waitForExistence(timeout: 5))
        app.buttons["chat.attach.photos"].tap()
        let onboarding = app.buttons["OK"]
        if onboarding.waitForExistence(timeout: 10) { onboarding.tap() }
        XCTAssertTrue(app.images.matching(identifier: "PXGGridLayout-Info").firstMatch.waitForExistence(timeout: 25))
        capture(app, "swiftchat-native-photos")
    }

    @MainActor func testBilibiliEmojiPickerInDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-conversation", "--uitest-dark"]
        app.launch()
        XCTAssertTrue(app.buttons["选择表情"].waitForExistence(timeout: 15))
        app.buttons["选择表情"].tap()
        XCTAssertTrue(app.buttons["😀"].waitForExistence(timeout: 5))
        app.buttons["😀"].tap()
        capture(app, "swiftchat-emotes")
        app.buttons["完成表情选择"].tap()
        XCTAssertTrue(app.buttons["chat.send"].waitForExistence(timeout: 5))
        capture(app, "swiftchat-emoji-draft")
    }

    @MainActor private func inputView(_ app: XCUIApplication) -> XCUIElement {
        if app.textViews.firstMatch.waitForExistence(timeout: 8) { return app.textViews.firstMatch }
        return app.textFields.firstMatch
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
