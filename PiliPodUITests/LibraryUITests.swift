import XCTest

final class LibraryUITests: XCTestCase {
    @MainActor
    func testLoadedCoversDoNotOverlapAndUnavailableRowsKeepVideoLayout() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["--library-layout-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let first = app.buttons["library.folder.1"]
        let second = app.buttons["library.folder.2"]
        let third = app.buttons["library.folder.3"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(second.exists)
        XCTAssertTrue(third.exists)
        XCTAssertGreaterThanOrEqual(second.frame.minX - first.frame.maxX, 14)
        XCTAssertGreaterThanOrEqual(third.frame.minY - first.frame.maxY, 18)
        XCTAssertEqual(first.frame.width, second.frame.width, accuracy: 1)
        XCTAssertEqual(first.frame.height, second.frame.height, accuracy: 1)
        capture(app, name: "双列收藏夹-已加载横向和竖向封面")

        first.tap()
        XCTAssertTrue(app.navigationBars["横向大尺寸封面收藏夹"].waitForExistence(timeout: 5))
        let invalid = app.buttons["library.media.101"]
        let valid = app.buttons["library.media.102"]
        let longInvalid = app.buttons["library.media.103"]
        XCTAssertTrue(invalid.waitForExistence(timeout: 5))
        XCTAssertTrue(valid.exists)
        XCTAssertTrue(longInvalid.exists)
        XCTAssertFalse(invalid.isEnabled)
        XCTAssertTrue(valid.isEnabled)
        XCTAssertEqual(invalid.frame.height, valid.frame.height, accuracy: 1)
        XCTAssertEqual(invalid.frame.width, valid.frame.width, accuracy: 1)
        XCTAssertEqual(longInvalid.frame.height, valid.frame.height, accuracy: 1)
        XCTAssertGreaterThanOrEqual(valid.frame.minY, invalid.frame.maxY)
        XCTAssertGreaterThanOrEqual(longInvalid.frame.minY, valid.frame.maxY)
        capture(app, name: "失效视频与正常视频统一排版")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLibraryEntriesAndLoginPrompts() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let mine = app.tabBars.buttons["我的"]
        XCTAssertTrue(mine.waitForExistence(timeout: 15))
        mine.tap()
        let subscriptions = app.buttons["my.all.subscriptions"]
        XCTAssertTrue(subscriptions.waitForExistence(timeout: 5))
        subscriptions.tap()
        XCTAssertTrue(app.navigationBars["我的订阅"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["登录"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let favorites = app.buttons["my.all.favorites"]
        for _ in 0..<4 {
            if favorites.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(favorites.waitForExistence(timeout: 5))
        favorites.tap()
        XCTAssertTrue(app.navigationBars["我的收藏"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["登录"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "我的收藏登录提示"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testMySectionsExpandIndependentlyAndFullListStillOpens() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 15))
        app.tabBars.buttons["我的"].tap()
        let history = app.buttons["my.section.history"]
        let offline = app.buttons["my.section.offline"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        if offline.value as? String == "已展开" { offline.tap() }
        if history.value as? String == "已展开" { history.tap() }
        history.tap()
        XCTAssertEqual(history.value as? String, "已展开")
        offline.tap()
        XCTAssertEqual(offline.value as? String, "已展开")
        XCTAssertEqual(history.value as? String, "已展开")
        history.tap()
        XCTAssertEqual(history.value as? String, "已收起")
        app.buttons["my.all.history"].tap()
        XCTAssertTrue(app.navigationBars["观看记录"].waitForExistence(timeout: 5))
    }
}
