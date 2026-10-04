import Combine
import Foundation

enum MyPageSection: String, CaseIterable, Codable, Identifiable {
    case offline, history, subscriptions, watchLater, favorites

    var id: String { rawValue }
    var title: String {
        switch self {
        case .offline: return "离线缓存"
        case .history: return "观看记录"
        case .subscriptions: return "我的订阅"
        case .watchLater: return "稍后再看"
        case .favorites: return "我的收藏"
        }
    }
    var symbol: String {
        switch self {
        case .offline: return "square.and.arrow.down"
        case .history: return "memories"
        case .subscriptions: return "rectangle.stack.badge.person.crop"
        case .watchLater: return "clock.badge"
        case .favorites: return "star.fill"
        }
    }
}

struct MyPageSettings: Codable, Equatable {
    static let defaultOrder: [MyPageSection] = [.history, .favorites, .offline, .subscriptions, .watchLater]
    var order: [MyPageSection] = Self.defaultOrder
    var expanded: Set<MyPageSection> = [.history, .favorites]

    var upgradingLegacyDefaults: MyPageSettings {
        order == MyPageSection.allCases && expanded.isEmpty ? MyPageSettings() : normalized
    }

    var normalized: MyPageSettings {
        var seen = Set<MyPageSection>()
        let unique = order.filter { seen.insert($0).inserted }
        return MyPageSettings(order: unique + Self.defaultOrder.filter { !seen.contains($0) }, expanded: expanded)
    }
}

@MainActor
final class MyPageSettingsStore: ObservableObject {
    static let shared = MyPageSettingsStore()
    private static let key = "myPage.settings"
    @Published var settings: MyPageSettings {
        didSet {
            if let data = try? JSONEncoder().encode(settings.normalized) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
        }
    }

    private init() {
        settings = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(MyPageSettings.self, from: $0) }?.upgradingLegacyDefaults ?? MyPageSettings()
    }
}
