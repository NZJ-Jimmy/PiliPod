import Combine
import Foundation

@MainActor
final class DynamicViewModel: ObservableObject {
    typealias PageLoader = (DynamicFeedFilter, String?) async throws -> UserSpaceDynamicPageResult

    @Published var category: DynamicCategory = .all
    @Published var selectedAuthor: DynamicFeedAuthor?
    @Published private(set) var authors: [DynamicFeedAuthor] = []
    @Published private(set) var items: [UserSpaceDynamicItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasMore = true

    var filter: DynamicFeedFilter { DynamicFeedFilter(category: category, authorMID: selectedAuthor?.mid) }

    private let loadPage: PageLoader
    private var offset: String?
    private var requestID = UUID()
    private var loadedFilter: DynamicFeedFilter?
    private var authorRequestID = UUID()

    init(loadPage: PageLoader? = nil) {
        self.loadPage = loadPage ?? { filter, offset in
            if let mid = filter.authorMID {
                return try await BiliAPI.shared.fetchUserSpaceDynamics(mid: mid, offset: offset)
            }
            return try await BiliAPI.shared.fetchAllDynamics(offset: offset, category: filter.category)
        }
    }

    func resetAccount() {
        requestID = UUID()
        authorRequestID = UUID()
        selectedAuthor = nil
        authors = []
        items = []
        offset = nil
        loadedFilter = nil
        errorMessage = nil
        hasMore = true
        isLoading = false
    }

    func refreshAuthors() async {
        let id = UUID()
        authorRequestID = id
        do {
            let result = try await BiliAPI.shared.fetchDynamicAuthors()
            guard authorRequestID == id, !Task.isCancelled else { return }
            authors = result
        } catch {
            // 推荐列表失败不阻断动态和“全部关注”选择器。
            guard authorRequestID == id else { return }
            if !(error is CancellationError), (error as? URLError)?.code != .cancelled {
                ErrorLogService.record(error, context: "加载动态 UP 主")
            }
        }
    }

    func refresh() async {
        requestID = UUID()
        loadedFilter = filter
        items = []
        offset = nil
        hasMore = true
        await loadBatch(id: requestID, filter: filter)
    }

    func loadMoreIfNeeded(current item: UserSpaceDynamicItem) async {
        guard item.id == items.last?.id else { return }
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore, loadedFilter == filter else { return }
        await loadBatch(id: requestID, filter: filter)
    }

    private func loadBatch(id: UUID, filter requestedFilter: DynamicFeedFilter) async {
        isLoading = true
        errorMessage = nil
        defer { if requestID == id { isLoading = false } }

        do {
            // 稀疏类别继续跨页查找，每批最多五页，仍有游标时提供“继续查找”。
            for _ in 0..<5 {
                let previousOffset = offset
                let page = try await loadPage(requestedFilter, previousOffset)
                guard requestID == id, filter == requestedFilter, !Task.isCancelled else { return }
                var seen = Set(items.map(\.id))
                let added = page.items.filter {
                    (requestedFilter.authorMID == nil || requestedFilter.category.matches($0)) && seen.insert($0.id).inserted
                }
                items.append(contentsOf: added)
                offset = page.nextOffset
                hasMore = page.hasMore && !(page.nextOffset ?? "").isEmpty && page.nextOffset != previousOffset
                if !added.isEmpty || !hasMore { break }
            }
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            guard requestID == id, filter == requestedFilter else { return }
            ErrorLogService.record(error, context: "加载筛选动态")
            errorMessage = error.localizedDescription
            // 保留卡片和游标，分页失败后可重试同一页。
        }
    }
}
