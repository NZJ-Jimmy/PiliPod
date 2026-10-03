import XCTest

final class LibraryUITests: XCTestCase {
    @MainActor
    func testLibraryEntriesAndLoginPrompts() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let mine = app.tabBars.buttons["我的"]
        XCTAssertTrue(mine.waitForExistence(timeout: 15))
        mine.tap()
        let subscriptions = app.buttons["我的订阅"]
        XCTAssertTrue(subscriptions.waitForExistence(timeout: 5))
        subscriptions.tap()
        XCTAssertTrue(app.navigationBars["我的订阅"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["登录"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let favorites = app.buttons["我的收藏"]
        XCTAssertTrue(favorites.waitForExistence(timeout: 5))
        favorites.tap()
        XCTAssertTrue(app.navigationBars["我的收藏"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["登录"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "我的收藏登录提示"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
