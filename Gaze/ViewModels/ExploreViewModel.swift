import SwiftUI
import Combine

// MARK: - Explore ViewModel

@MainActor
final class ExploreViewModel: ObservableObject {

    @Published var selectedCategory: StyleCategory? = nil
    @Published var allOutfits: [Outfit] = []
    @Published var isLoading = true
    @Published var searchText = ""
    @Published var selectedOutfit: Outfit? = nil
    @Published var isAISearching = false
    @Published var isLoadingMore = false

    private let explorePageSize = 50
    private var exploreServerOffset = 0
    private var canLoadMoreExplore = true
    private var aiExpansion: AIQueryExpansion? = nil
    private var cancellables = Set<AnyCancellable>()
    private var aiSearchTask: Task<Void, Never>? = nil

    init() {
        // Debounce search -> trigger AI expansion after 420ms of inactivity
        $searchText
            .debounce(for: .milliseconds(420), scheduler: DispatchQueue.main)
            .sink { [weak self] query in self?.triggerAISearch(query: query) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitLiked)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let id = n.object as? UUID,
                      let idx = self.allOutfits.firstIndex(where: { $0.id == id }) else { return }
                self.allOutfits[idx].isRatedByCurrentUser = true
                self.allOutfits[idx].fireCount += 1
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitUnliked)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let id = n.object as? UUID,
                      let idx = self.allOutfits.firstIndex(where: { $0.id == id }) else { return }
                self.allOutfits[idx].isRatedByCurrentUser = false
                self.allOutfits[idx].fireCount = max(0, self.allOutfits[idx].fireCount - 1)
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitSaved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let outfit = n.object as? Outfit,
                      let idx = self.allOutfits.firstIndex(where: { $0.id == outfit.id }) else { return }
                self.allOutfits[idx].isSaved = true
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitUnsaved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let id = n.object as? UUID,
                      let idx = self.allOutfits.firstIndex(where: { $0.id == id }) else { return }
                self.allOutfits[idx].isSaved = false
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let id = n.object as? UUID else { return }
                self.allOutfits.removeAll { $0.id == id }
            }.store(in: &cancellables)
    }

    // MARK: - Filtered Outfits

    var filteredOutfits: [Outfit] {
        var results = allOutfits

        // Category chip filter
        if let cat = selectedCategory {
            results = results.filter { $0.category == cat }
        }

        guard !searchText.isEmpty else { return results }

        // AI expansion available -> semantic filter
        if let ai = aiExpansion {
            if ai.matchAll { return results }
            return results.filter { outfit in
                let catMatch = !ai.categories.isEmpty && ai.categories.contains(outfit.category)
                let kwMatch  = ai.keywords.contains { kw in
                    outfit.caption.localizedCaseInsensitiveContains(kw) ||
                    outfit.brands.contains { brand in brand.localizedCaseInsensitiveContains(kw) } ||
                    (outfit.user?.username.localizedCaseInsensitiveContains(kw) == true) ||
                    outfit.city.localizedCaseInsensitiveContains(kw)
                }
                return catMatch || kwMatch
            }
        }

        // Fallback text filter while AI is loading
        return results.filter {
            $0.user?.username.localizedCaseInsensitiveContains(searchText) == true ||
            $0.caption.localizedCaseInsensitiveContains(searchText) ||
            $0.brands.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            $0.city.localizedCaseInsensitiveContains(searchText)
        }
    }

    var trendingOutfits: [Outfit] {
        Array(allOutfits.sorted { $0.fireCount > $1.fireCount }.prefix(8))
    }

    // MARK: - Load

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        if allOutfits.isEmpty { isLoading = true }
        do {
            let userId = SupabaseManager.shared.currentUserId
            allOutfits = try await SupabaseService.shared.fetchExploreFeed(currentUserId: userId, limit: explorePageSize)
            exploreServerOffset = allOutfits.count
            canLoadMoreExplore = allOutfits.count >= explorePageSize
        } catch {
            AppLogger.error("Explore feed load failed, preserving existing data", category: .feed, properties: ["error": error.localizedDescription])
        }
        isLoading = false
    }

    func loadMore() {
        guard !isLoadingMore, canLoadMoreExplore, searchText.isEmpty else { return }
        isLoadingMore = true
        Task {
            do {
                let userId = SupabaseManager.shared.currentUserId
                let more = try await SupabaseService.shared.fetchExploreFeed(
                    currentUserId: userId, limit: explorePageSize, offset: exploreServerOffset)
                if more.count < explorePageSize { canLoadMoreExplore = false }
                exploreServerOffset += more.count
                let existingIds = Set(allOutfits.map { $0.id })
                let newItems = more.filter { !existingIds.contains($0.id) }
                allOutfits.append(contentsOf: newItems)
                AppLogger.info("Explore load more completed", category: .feed, properties: ["new_items": "\(newItems.count)"])
            } catch {
                AppLogger.error("Explore load more failed", category: .feed, properties: ["error": error.localizedDescription])
            }
            isLoadingMore = false
        }
    }

    func selectCategory(_ cat: StyleCategory?) {
        GazeHaptics.selection()
        withAnimation(GazeAnimations.springSnappy) {
            selectedCategory = (selectedCategory == cat) ? nil : cat
        }
    }

    // MARK: - AI Search

    private func triggerAISearch(query: String) {
        aiSearchTask?.cancel()
        aiExpansion = nil
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            isAISearching = false
            return
        }
        isAISearching = true
        aiSearchTask = Task {
            let result = await AISearchService.shared.expandQuery(query)
            guard !Task.isCancelled else { return }
            aiExpansion = result
            isAISearching = false
        }
    }
}
