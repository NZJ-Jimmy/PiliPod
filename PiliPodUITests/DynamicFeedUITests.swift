import XCTest

final class DynamicFeedUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launchFeed() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dynamic-feed-ui-testing", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["dynamicFeed.fixture0.BV1xx411c7mD"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    func testPullToRefreshShowsReplacementWithoutContinueButton() {
        let app = launchFeed()
        let first = app.buttons["dynamicFeed.fixture0.BV1xx411c7mD"]
        XCTAssertTrue(first.label.contains("刷新1"))
        app.scrollViews["dynamicFeedScroll"].swipeDown()
        let refreshed = NSPredicate(format: "label CONTAINS %@", "刷新2")
        expectation(for: refreshed, evaluatedWith: first)
        waitForExpectations(timeout: 15)
        XCTAssertFalse(app.buttons["继续查找"].exists)
        XCTAssertFalse(app.staticTexts["尚未找到匹配动态"].exists)
        attach(app, name: "Refreshed dynamic feed")
    }

    @MainActor
    func testAuthorStripDoesNotRefreshOrMoveVertically() {
        let app = launchFeed()
        let strip = app.scrollViews["dynamicAuthorStrip"]
        XCTAssertTrue(strip.exists)
        let before = strip.frame
        let start = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        let end = start.withOffset(CGVector(dx: 0, dy: 150))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertEqual(strip.frame.minY, before.minY, accuracy: 2)
        XCTAssertTrue(app.buttons["dynamicFeed.fixture0.BV1xx411c7mD"].label.contains("刷新1"))
        attach(app, name: "Author strip remains fixed")
    }

    @MainActor
    func testInteractiveVideoReturnPreservesFeedAndScrollPosition() {
        let app = launchFeed()
        let feed = app.scrollViews["dynamicFeedScroll"]
        let video = app.buttons["dynamicFeed.fixture3.BV1xx411c7mD"]
        for _ in 0..<8 {
            if video.isHittable { break }
            feed.swipeUp()
        }
        XCTAssertTrue(video.isHittable)
        let originalY = video.frame.minY
        video.tap()
        let hidden = NSPredicate(format: "hittable == false")
        expectation(for: hidden, evaluatedWith: video)
        waitForExpectations(timeout: 10)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.55))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)
        let returned = NSPredicate(format: "hittable == true")
        expectation(for: returned, evaluatedWith: video)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(video.label.contains("刷新1"))
        XCTAssertEqual(video.frame.minY, originalY, accuracy: 8)
        attach(app, name: "Interactive return retains scroll position")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
