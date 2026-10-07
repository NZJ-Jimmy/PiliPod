import Combine
import Foundation

@MainActor
final class DynamicAuthorPickerModel: ObservableObject {
    @Published private(set) var users: [FollowingUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasMore = true

    private let mid: Int
    private var keyword = ""
    private var page = 0
    private var requestID = UUID()

    init(mid: Int) { self.mid = mid }

    func prepareSearch(_ text: String) {
        requestID = UUID()
        keyword = text.trimmingCharacters(in: .whitespacesAndNewlines)
        page = 0
        users = []
        errorMessage = nil
        hasMore = true
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        let id = requestID
        let nextPage = page + 1
        isLoading = true
        errorMessage = nil
        defer { if requestID == id { isLoading = false } }
        do {
            let result: FollowingData
            if keyword.isEmpty {
                result = try await BiliAPI.shared.fetchFollowingList(vmid: mid, pn: nextPage, orderType: "attention")
            } else {
                result = try await BiliAPI.shared.searchFollowingList(vmid: mid, keyword: keyword, pn: nextPage)
            }
            guard requestID == id, !Task.isCancelled else { return }
            let received = result.list ?? []
            var seen = Set(users.map(\.mid))
            users.append(contentsOf: received.filter { seen.insert($0.mid).inserted })
            page = nextPage
            hasMore = !received.isEmpty && (result.total > 0 ? page * 50 < result.total : received.count == 50)
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            guard requestID == id else { return }
            errorMessage = error.localizedDescription
            ErrorLogService.record(error, context: "选择动态 UP 主")
        }
    }
}
