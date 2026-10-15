import Combine
import Foundation

@MainActor
final class LibraryViewModel<Entry: Identifiable>: ObservableObject {
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = true
    @Published private(set) var errorMessage: String?
    private var nextPage = 1
    private var generation = 0
    private let loader: (Int) async throws -> LibraryPage<Entry>

    init(loader: @escaping (Int) async throws -> LibraryPage<Entry>) {
        self.loader = loader
    }

    func reset() {
        generation += 1
        entries = []
        nextPage = 1
        hasMore = true
        isLoading = false
        errorMessage = nil
    }

    func refresh() async {
        reset()
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        let currentGeneration = generation
        isLoading = true
        errorMessage = nil
        defer { if currentGeneration == generation { isLoading = false } }
        do {
            let result = try await loader(nextPage)
            guard currentGeneration == generation, !Task.isCancelled else { return }
            var seen = Set(entries.map(\.id))
            entries.append(contentsOf: result.entries.filter { seen.insert($0.id).inserted })
            hasMore = result.hasMore && !result.entries.isEmpty
            nextPage += 1
        } catch {
            guard currentGeneration == generation, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            ErrorLogService.record(error, context: "加载收藏与订阅")
        }
    }

    func remove(id: Entry.ID) {
        entries.removeAll { $0.id == id }
    }
}
