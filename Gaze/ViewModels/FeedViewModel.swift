import SwiftUI
import Combine

// MARK: - Feed Mode

enum FeedMode: String, CaseIterable {
    case friends   = "Friends"
    case following = "Following"
}

// MARK: - Home Feed ViewModel

@MainActor
final class HomeFeedViewModel: ObservableObject {

    @Published var feedMode: FeedMode = .friends
    @Published var friendsOutfits: [Outfit] = []
    @Published var followingOutfits: [Outfit] = []
    @Published var isLoading: Bool = true
    @Published var hasError: Bool = false
    @Published var isLoadingMore: Bool = false

    private let friendsPageSize = 20
    private let followingPageSize = 30
    private var friendsServerOffset = 0
    private var followingServerOffset = 0
    private var canLoadMoreFriends = true
    private var canLoadMoreFollowing = true

    var outfits: [Outfit] {
        feedMode == .friends ? friendsOutfits : followingOutfits
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .gazeNewPost)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, let outfit = notification.object as? Outfit else { return }
                if !self.friendsOutfits.contains(where: { $0.id == outfit.id }) {
                    self.friendsOutfits.insert(outfit, at: 0)
                }
                // Only show in Following feed if post is public (friends-only posts are mutual-follow only)
                if outfit.visibility == .everyone,
                   !self.followingOutfits.contains(where: { $0.id == outfit.id }) {
                    self.followingOutfits.insert(outfit, at: 0)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitLiked)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let id = n.object as? UUID else { return }
                if let idx = self.friendsOutfits.firstIndex(where: { $0.id == id }) {
                    self.friendsOutfits[idx].isRatedByCurrentUser = true
                    self.friendsOutfits[idx].fireCount += 1
                }
                if let idx = self.followingOutfits.firstIndex(where: { $0.id == id }) {
                    self.followingOutfits[idx].isRatedByCurrentUser = true
                    self.followingOutfits[idx].fireCount += 1
                }
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitUnliked)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let id = n.object as? UUID else { return }
                if let idx = self.friendsOutfits.firstIndex(where: { $0.id == id }) {
                    self.friendsOutfits[idx].isRatedByCurrentUser = false
                    self.friendsOutfits[idx].fireCount = max(0, self.friendsOutfits[idx].fireCount - 1)
                }
                if let idx = self.followingOutfits.firstIndex(where: { $0.id == id }) {
                    self.followingOutfits[idx].isRatedByCurrentUser = false
                    self.followingOutfits[idx].fireCount = max(0, self.followingOutfits[idx].fireCount - 1)
                }
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitSaved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let outfit = n.object as? Outfit else { return }
                if let idx = self.friendsOutfits.firstIndex(where: { $0.id == outfit.id }) {
                    self.friendsOutfits[idx].isSaved = true
                }
                if let idx = self.followingOutfits.firstIndex(where: { $0.id == outfit.id }) {
                    self.followingOutfits[idx].isSaved = true
                }
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitUnsaved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let id = n.object as? UUID else { return }
                if let idx = self.friendsOutfits.firstIndex(where: { $0.id == id }) {
                    self.friendsOutfits[idx].isSaved = false
                }
                if let idx = self.followingOutfits.firstIndex(where: { $0.id == id }) {
                    self.followingOutfits[idx].isSaved = false
                }
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let id = n.object as? UUID else { return }
                self.friendsOutfits.removeAll { $0.id == id }
                self.followingOutfits.removeAll { $0.id == id }
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitCommented)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let id = n.object as? UUID else { return }
                if let idx = self.friendsOutfits.firstIndex(where: { $0.id == id }) {
                    self.friendsOutfits[idx].commentCount += 1
                }
                if let idx = self.followingOutfits.firstIndex(where: { $0.id == id }) {
                    self.followingOutfits[idx].commentCount += 1
                }
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeCommentDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                guard let self, let id = n.object as? UUID else { return }
                if let idx = self.friendsOutfits.firstIndex(where: { $0.id == id }) {
                    self.friendsOutfits[idx].commentCount = max(0, self.friendsOutfits[idx].commentCount - 1)
                }
                if let idx = self.followingOutfits.firstIndex(where: { $0.id == id }) {
                    self.followingOutfits[idx].commentCount = max(0, self.followingOutfits[idx].commentCount - 1)
                }
            }.store(in: &cancellables)

        // Refresh both feeds whenever a follow/unfollow happens
        NotificationCenter.default.publisher(for: .gazeFollowStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)
    }

    func load() {
        isLoading = true
        hasError = false
        AppLogger.info("Feed load started", category: .feed)
        Task {
            guard let userId = SupabaseManager.shared.currentUserId else {
                AppLogger.warning("Feed load skipped — no authenticated user", category: .feed)
                friendsOutfits = []
                followingOutfits = []
                isLoading = false
                return
            }
            do {
                async let friendsReq   = SupabaseService.shared.fetchFeed(currentUserId: userId)
                async let followingReq = SupabaseService.shared.fetchFollowingFeed(currentUserId: userId)
                let (friends, following) = try await (friendsReq, followingReq)
                friendsOutfits   = friends
                followingOutfits = following
                friendsServerOffset = friends.count
                followingServerOffset = following.count
                canLoadMoreFriends = friends.count >= friendsPageSize
                canLoadMoreFollowing = following.count >= followingPageSize
                AppLogger.info("Feed load completed", category: .feed, properties: ["friends": "\(friends.count)", "following": "\(following.count)"])
            } catch {
                hasError = true
                AppLogger.error("Feed load failed", category: .feed, properties: ["error": error.localizedDescription])
            }
            isLoading = false
        }
    }

    func refresh() async {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        AppLogger.debug("Feed refresh started", category: .feed)
        do {
            async let friendsReq   = SupabaseService.shared.fetchFeed(currentUserId: userId)
            async let followingReq = SupabaseService.shared.fetchFollowingFeed(currentUserId: userId)
            let (friends, following) = try await (friendsReq, followingReq)
            friendsOutfits   = friends
            followingOutfits = following
            friendsServerOffset = friends.count
            followingServerOffset = following.count
            canLoadMoreFriends = friends.count >= friendsPageSize
            canLoadMoreFollowing = following.count >= followingPageSize
            AppLogger.info("Feed refresh completed", category: .feed, properties: ["friends": "\(friends.count)", "following": "\(following.count)"])
        } catch {
            hasError = true
            AppLogger.error("Feed refresh failed", category: .feed, properties: ["error": error.localizedDescription])
        }
    }

    func loadMore() {
        let mode = feedMode
        guard !isLoadingMore else { return }
        guard mode == .friends ? canLoadMoreFriends : canLoadMoreFollowing else { return }

        isLoadingMore = true
        Task {
            guard let userId = SupabaseManager.shared.currentUserId else {
                isLoadingMore = false
                return
            }
            do {
                if mode == .friends {
                    let more = try await SupabaseService.shared.fetchFeed(
                        currentUserId: userId, limit: friendsPageSize, offset: friendsServerOffset)
                    if more.count < friendsPageSize { canLoadMoreFriends = false }
                    friendsServerOffset += more.count
                    let existingIds = Set(friendsOutfits.map { $0.id })
                    let newItems = more.filter { !existingIds.contains($0.id) }
                    friendsOutfits.append(contentsOf: newItems)
                } else {
                    let more = try await SupabaseService.shared.fetchFollowingFeed(
                        currentUserId: userId, limit: followingPageSize, offset: followingServerOffset)
                    if more.count < followingPageSize { canLoadMoreFollowing = false }
                    followingServerOffset += more.count
                    let existingIds = Set(followingOutfits.map { $0.id })
                    let newItems = more.filter { !existingIds.contains($0.id) }
                    followingOutfits.append(contentsOf: newItems)
                }
                AppLogger.info("Load more completed", category: .feed, properties: ["mode": mode.rawValue])
            } catch {
                AppLogger.error("Load more failed", category: .feed, properties: ["mode": mode.rawValue, "error": error.localizedDescription])
            }
            isLoadingMore = false
        }
    }

    // MARK: - Optimistic fire toggle

    func toggleFire(outfit: Outfit) {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        let wasFired = outfit.isRatedByCurrentUser
        updateBothFeeds(id: outfit.id) {
            $0.isRatedByCurrentUser = !wasFired
            $0.fireCount += wasFired ? -1 : 1
        }
        Task {
            do {
                if wasFired { try await SupabaseService.shared.removeFire(outfitId: outfit.id, userId: userId) }
                else        { try await SupabaseService.shared.addFire(outfitId: outfit.id, userId: userId) }
                AppLogger.debug("Fire toggled", category: .feed, properties: ["outfit_id": outfit.id.uuidString, "action": wasFired ? "unfired" : "fired"])
            } catch {
                AppLogger.error("Fire toggle failed, rolling back", category: .feed, properties: ["outfit_id": outfit.id.uuidString, "error": error.localizedDescription])
                updateBothFeeds(id: outfit.id) {
                    $0.isRatedByCurrentUser = wasFired
                    $0.fireCount += wasFired ? 1 : -1
                }
            }
        }
    }

    // MARK: - Optimistic save toggle

    func toggleSave(outfit: Outfit) {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        let wasSaved = outfit.isSaved
        updateBothFeeds(id: outfit.id) { $0.isSaved = !wasSaved }
        Task {
            do {
                if wasSaved {
                    try await SupabaseService.shared.unsaveOutfit(outfitId: outfit.id, userId: userId)
                    NotificationCenter.default.post(name: .gazeOutfitUnsaved, object: outfit.id)
                } else {
                    try await SupabaseService.shared.saveOutfit(outfitId: outfit.id, userId: userId)
                    let saved = friendsOutfits.first(where: { $0.id == outfit.id })
                              ?? followingOutfits.first(where: { $0.id == outfit.id })
                    NotificationCenter.default.post(name: .gazeOutfitSaved, object: saved)
                }
                AppLogger.debug("Save toggled", category: .feed, properties: ["outfit_id": outfit.id.uuidString, "action": wasSaved ? "unsaved" : "saved"])
            } catch {
                AppLogger.error("Save toggle failed, rolling back", category: .feed, properties: ["outfit_id": outfit.id.uuidString, "error": error.localizedDescription])
                updateBothFeeds(id: outfit.id) { $0.isSaved = wasSaved }
            }
        }
    }

    private func updateBothFeeds(id: UUID, update: (inout Outfit) -> Void) {
        if let i = friendsOutfits.firstIndex(where: { $0.id == id }) { update(&friendsOutfits[i]) }
        if let i = followingOutfits.firstIndex(where: { $0.id == id }) { update(&followingOutfits[i]) }
    }
}
