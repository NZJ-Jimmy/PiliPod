import Foundation
import Testing
@testable import PiliPod

struct MyPageSettingsTests {
    @Test func incompleteAndDuplicateOrderKeepsEverySectionExactlyOnce() {
        let settings = MyPageSettings(order: [.favorites, .history, .favorites], expanded: [.history]).normalized
        #expect(settings.order == [.favorites, .history, .offline, .subscriptions, .watchLater])
        #expect(Set(settings.order) == Set(MyPageSection.allCases))
        #expect(settings.expanded == [.history])
    }

    @Test func layoutPreferencesSurviveBackupRoundTrip() throws {
        let settings = MyPageSettings(order: Array(MyPageSection.allCases.reversed()), expanded: [.history, .watchLater])
        let snapshot = AppSettingsBackupPayload.SettingsSnapshot(myPage: settings)
        let decoded = try JSONDecoder().decode(
            AppSettingsBackupPayload.SettingsSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        #expect(decoded.myPage == settings)
    }

    @Test func olderBackupsRemainReadable() throws {
        let decoded = try JSONDecoder().decode(
            AppSettingsBackupPayload.SettingsSnapshot.self,
            from: Data("{}".utf8)
        )
        #expect(decoded.myPage == nil)
        #expect(MyPageSettings().expanded == [.history, .favorites])
    }

    @Test func newDefaultsAndLegacyMigrationKeepCustomPreferences() {
        #expect(Array(MyPageSettings().order.prefix(2)) == [.history, .favorites])
        let legacy = MyPageSettings(order: MyPageSection.allCases, expanded: [])
        #expect(legacy.upgradingLegacyDefaults == MyPageSettings())
        let custom = MyPageSettings(order: [.subscriptions, .history, .favorites, .offline, .watchLater], expanded: [.subscriptions])
        #expect(custom.upgradingLegacyDefaults == custom)
    }
}
