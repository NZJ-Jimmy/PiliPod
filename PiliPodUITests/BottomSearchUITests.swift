import XCTest

final class BottomSearchUITests: XCTestCase {
    @MainActor
    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    @MainActor
    func testSearchExpandsAtBottomAndSubmitsWithKeyboard() {
        let app = launchApp()
        let search = app.tabBars.buttons["搜索"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        XCTAssertFalse(app.searchFields.firstMatch.exists)
        capture(app, name: "底部独立搜索入口")
        search.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(field.frame.midY, app.frame.midY)
        // A fresh simulator can cover the keyboard with the QuickPath tutorial.
        for title in ["Continue", "继续"] {
            let tutorialButton = app.buttons[title]
            if tutorialButton.exists { tutorialButton.tap() }
        }
        field.typeText("pilipod")
        capture(app, name: "底部展开输入栏")
        let submit = app.keyboards.buttons["Search"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertTrue(submit.isHittable)
        submit.tap()
        XCTAssertTrue(app.staticTexts["综合"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["视频"].exists)
        XCTAssertTrue(app.staticTexts["用户"].exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        capture(app, name: "提交搜索显示结果分类")
        app.tabBars.buttons["首页"].tap()
        XCTAssertTrue(search.exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        search.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testMessagesAreNextToSettingsOnMyPage() {
        let app = launchApp()
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["my.messages"].isHittable)
        app.tabBars.buttons["我的"].tap()
        let messages = app.buttons["my.messages"]
        let settings = app.buttons["my.settings"]
        XCTAssertTrue(messages.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.exists)
        XCTAssertFalse(app.searchFields.firstMatch.exists)
        XCTAssertEqual(messages.frame.midY, settings.frame.midY, accuracy: 2)
        XCTAssertLessThan(messages.frame.maxX, settings.frame.minX)
        capture(app, name: "我的页私信与设置并列")
        messages.tap()
        XCTAssertTrue(app.navigationBars["消息"].waitForExistence(timeout: 5))
        capture(app, name: "原生消息页")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(messages.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
