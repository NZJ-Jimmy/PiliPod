import Combine
import Foundation

@MainActor
final class DynamicViewModel: ObservableObject {
    typealias PageLoader = (DynamicFeedFilter, String?) async throws -> UserSpaceDynamicPageResult
    typealias AuthorLoader = () async throws -> [DynamicFeedAuthor]

    @Published var category: DynamicCategory = .all
    @Published var selectedAuthor: DynamicFeedAuthor?
    @Published private(set) var authors: [DynamicFeedAuthor] = []
    @Published private(set) var items: [UserSpaceDynamicItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasMore = true
    @Published private(set) var needsManualContinuation = false

    var filter: DynamicFeedFilter { DynamicFeedFilter(category: category, authorMID: selectedAuthor?.mid) }

    private let loadPage: PageLoader?
    private let loadAuthors: AuthorLoader
    private var offset: String?
    private var requestID = UUID()
    private var loadedFilter: DynamicFeedFilter?
    private var loadingFilter: DynamicFeedFilter?
    private var failedFilter: DynamicFeedFilter?
    private var hasLoadedAuthors = false
    private var authorRequestID = UUID()

    init(loadAuthors: AuthorLoader? = nil, loadPage: PageLoader? = nil) {
        self.loadPage = loadPage
        self.loadAuthors = loadAuthors ?? { try await BiliAPI.shared.fetchDynamicAuthors() }
    }

    func resetAccount() {
        requestID = UUID()
        authorRequestID = UUID()
        selectedAuthor = nil
        authors = []
        hasLoadedAuthors = false
        items = []
        offset = nil
        loadedFilter = nil
        loadingFilter = nil
        failedFilter = nil
        errorMessage = nil
        hasMore = true
        needsManualContinuation = false
        isLoading = false
    }

    func loadAuthorsIfNeeded() async {
        guard !hasLoadedAuthors else { return }
        await refreshAuthors()
    }

    func refreshAuthors() async {
        let id = UUID()
        authorRequestID = id
        do {
            let result = try await loadAuthors()
            guard authorRequestID == id, !Task.isCancelled else { return }
            authors = result
            hasLoadedAuthors = true
        } catch {
            guard authorRequestID == id else { return }
            if !(error is CancellationError), (error as? URLError)?.code != .cancelled {
                ErrorLogService.record(error, context: "加载动态 UP 主")
            }
        }
    }

    // NavigationStack 返回或切换 tab 会重新执行 .task，同一筛选已有结果时保留列表和游标。
    func loadIfNeeded() async {
        guard failedFilter != filter else { return }
        guard loadedFilter != filter else { return }
        guard !isLoading || loadingFilter != filter else { return }
        await refresh()
    }

    func refresh() async {
        let requestedFilter = filter
        requestID = UUID()
        if loadedFilter != requestedFilter {
            items = []
            offset = nil
            hasMore = true
            needsManualContinuation = false
            loadedFilter = nil
        }
        // 同一筛选下保留旧卡片；仅请求成功后一次替换，避免移除刷新宿主而取消任务。
        await loadBatch(id: requestID, filter: requestedFilter, replacing: true)
    }

    func loadMoreIfNeeded(current item: UserSpaceDynamicItem) async {
        guard item.id == items.last?.id, !needsManualContinuation, errorMessage == nil else { return }
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore, loadedFilter == filter else { return }
        await loadBatch(id: requestID, filter: filter, replacing: false)
    }

    private func loadBatch(id: UUID, filter requestedFilter: DynamicFeedFilter, replacing: Bool) async {
        isLoading = true
        loadingFilter = requestedFilter
        errorMessage = nil
        failedFilter = nil
        defer {
            if requestID == id {
                isLoading = false
                loadingFilter = nil
            }
        }

        var nextOffset = replacing ? nil : offset
        var nextHasMore = true
        var added: [UserSpaceDynamicItem] = []
        var seen = Set(replacing ? [] : items.map(\.id))
        var visitedOffsets = Set<String>()
        let requestedAuthor = selectedAuthor

        do {
            // 作者和类别均由 API 筛选，每次只请求一页，空页保留游标供手动继续。
            try Task.checkCancellation()
            let previousOffset = nextOffset
            if let previousOffset { visitedOffsets.insert(previousOffset) }
            let page: UserSpaceDynamicPageResult
            if let loadPage {
                page = try await loadPage(requestedFilter, previousOffset)
            } else {
                page = try await BiliAPI.shared.fetchFilteredDynamics(filter: requestedFilter, author: requestedAuthor, offset: previousOffset)
            }
            try Task.checkCancellation()
            guard requestID == id, filter == requestedFilter else { return }
            added.append(contentsOf: page.items.filter {
                seen.insert($0.id).inserted
            })
            nextOffset = page.nextOffset
            nextHasMore = page.hasMore && !(nextOffset ?? "").isEmpty
                && !visitedOffsets.contains(nextOffset ?? "")

            // 游标与卡片原子提交，失败或取消不丢掉上一份完整结果。
            if replacing { items = added }
            else { items.append(contentsOf: added) }
            offset = nextOffset
            hasMore = nextHasMore
            needsManualContinuation = added.isEmpty && nextHasMore
            loadedFilter = requestedFilter
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            guard requestID == id, filter == requestedFilter else { return }
            ErrorLogService.record(error, context: "加载筛选动态")
            failedFilter = requestedFilter
            errorMessage = error.localizedDescription
        }
    }
}
