import XCTest

final class DynamicFeedUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launchFeed() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dynamic-feed-ui-testing", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["dynamicFeed.fixture0.BV1zz411zzzz"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    func testPullToRefreshShowsReplacementWithoutContinueButton() {
        let app = launchFeed()
        let first = app.buttons["dynamicFeed.fixture0.BV1zz411zzzz"]
        XCTAssertTrue(first.label.contains("刷新1"))
        let feed = app.descendants(matching: .any)["dynamicFeedScroll"]
        let start = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
        defer { attach(app, name: "Pull-to-refresh result") }
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
        XCTAssertTrue(app.buttons["dynamicFeed.fixture0.BV1zz411zzzz"].label.contains("刷新1"))
        attach(app, name: "Author strip remains fixed")
    }

    @MainActor
    func testInteractiveVideoReturnPreservesFeedAndScrollPosition() {
        let app = launchFeed()
        let feed = app.descendants(matching: .any)["dynamicFeedScroll"]
        let video = app.buttons["dynamicFeed.fixture3.BV1zz411zzzz"]
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
        app.pinch(withScale: 0.4, velocity: -1)
        let returned = NSPredicate(format: "hittable == true")
        expectation(for: returned, evaluatedWith: video)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(video.label.contains("刷新1"))
        XCTAssertEqual(video.frame.minY, originalY, accuracy: 8)
        attach(app, name: "Interactive return retains scroll position")
    }

    @MainActor
    func testArticleZoomReturnPreservesFeed() {
        let app = launchFeed()
        let feed = app.descendants(matching: .any)["dynamicFeedScroll"]
        let article = app.buttons["dynamicFeed.fixture1.preview"]
        for _ in 0..<8 {
            if article.isHittable { break }
            feed.swipeUp()
        }
        XCTAssertTrue(article.isHittable)
        let originalY = article.frame.minY
        article.tap()
        XCTAssertTrue(app.navigationBars["测试专栏 · 刷新1"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(article.waitForExistence(timeout: 10))
        XCTAssertTrue(article.isHittable)
        XCTAssertEqual(article.frame.minY, originalY, accuracy: 8)
        attach(app, name: "Article zoom return retains position")
    }

    @MainActor
    func testTextDynamicZoomOpensDetail() {
        let app = launchFeed()
        let feed = app.descendants(matching: .any)["dynamicFeedScroll"]
        let text = app.descendants(matching: .any)["dynamicFeed.fixture2.text"]
        for _ in 0..<8 {
            if text.exists && text.isHittable { break }
            let start = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            let end = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(text.isHittable)
        let originalY = text.frame.minY
        text.tap()
        XCTAssertTrue(app.navigationBars["动态详情"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(text.isHittable)
        XCTAssertEqual(text.frame.minY, originalY, accuracy: 8)
        attach(app, name: "Text dynamic zoom return retains position")
    }

    @MainActor
    func testSelectedAuthorArticleShowsOnlyArticles() {
        let app = launchFeed()
        app.scrollViews["dynamicAuthorStrip"].buttons["测试 UP"].tap()
        app.segmentedControls.buttons["专栏"].tap()
        XCTAssertTrue(app.buttons["dynamicFeed.fixture1.preview"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["dynamicFeed.fixture0.BV1zz411zzzz"].exists)
        XCTAssertFalse(app.buttons["查看更早动态"].exists)
        attach(app, name: "Author article server-filtered feed")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
