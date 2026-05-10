import SwiftUI
import Combine
import Foundation

// MARK: - Profile ViewModel

@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var user: GazeUser
    @Published var outfits: [Outfit] = []
    @Published var savedOutfits: [Outfit] = []
    @Published var challengeEntries: [ChallengeEntry] = []
    @Published var isLoading = true
    @Published var showEditProfile = false
    @Published var showSettings = false
    @Published var selectedOutfit: Outfit? = nil
    @Published var activeGridTab: ProfileGridTab = .posts
    @Published var showAvatarUploadError = false

    enum ProfileGridTab: String, CaseIterable {
        case posts  = "Posts"
        case saved  = "Saved"
        case arena  = "Runway"
    }

    var displayedOutfits: [Outfit] {
        guard activeGridTab != .arena else { return [] }
        let base = activeGridTab == .posts ? outfits : savedOutfits
        let hasImage = base.filter {
            $0.imageURL != nil || MockDataService.shared.localImage(for: $0.id) != nil
        }
        if activeGridTab == .posts {
            let challengeOutfitIds = Set(challengeEntries.compactMap { $0.outfit?.id })
            return hasImage.filter { !challengeOutfitIds.contains($0.id) }
        }
        return hasImage
    }

    var displayedPostCountForProfile: Int {
        if isLoading { return user.outfitCount }
        let challengeOutfitIds = Set(challengeEntries.compactMap { $0.outfit?.id })
        return outfits.filter { o in
            (o.imageURL != nil || MockDataService.shared.localImage(for: o.id) != nil)
                && !challengeOutfitIds.contains(o.id)
        }.count
    }

    private var cancellables = Set<AnyCancellable>()

    var weeklyFiresCount: Int {
        outfits.prefix(5).reduce(0) { $0 + $1.fireCount }
    }

    var topOutfit: Outfit? {
        outfits.max { $0.averageRating < $1.averageRating }
    }

    init(user: GazeUser) {
        self.user = user
        NotificationCenter.default.publisher(for: .gazeNewPost)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, let outfit = notification.object as? Outfit,
                      outfit.userId == self.user.id else { return }
                var mine = outfit
                mine.user = self.user
                self.outfits.insert(mine, at: 0)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitSaved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, let outfit = notification.object as? Outfit else { return }
                if !self.savedOutfits.contains(where: { $0.id == outfit.id }) {
                    var saved = outfit
                    saved.isSaved = true
                    self.savedOutfits.insert(saved, at: 0)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitUnsaved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, let outfitId = notification.object as? UUID else { return }
                self.savedOutfits.removeAll { $0.id == outfitId }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeOutfitDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, let id = notification.object as? UUID else { return }
                self.outfits.removeAll { $0.id == id }
                self.savedOutfits.removeAll { $0.id == id }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeChallengeEntryDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, let id = notification.object as? UUID else { return }
                self.challengeEntries.removeAll { $0.id == id }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gazeChallengeEntryAdded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, let entry = notification.object as? ChallengeEntry else { return }
                if !self.challengeEntries.contains(where: { $0.id == entry.id }) {
                    self.challengeEntries.insert(entry, at: 0)
                }
            }
            .store(in: &cancellables)
    }

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        isLoading = true
        let currentUserId = SupabaseManager.shared.currentUserId ?? user.id
        AppLogger.debug("Profile load started", category: .profile, properties: ["user_id": user.id.uuidString])

        async let p = SupabaseService.shared.fetchProfileOutfits(
            userId: user.id, currentUserId: currentUserId)
        async let s = SupabaseService.shared.fetchSavedOutfits(userId: currentUserId)
        async let e = SupabaseService.shared.fetchUserChallengeEntries(userId: user.id)

        if let fetched = try? await p { outfits = fetched }
        else { AppLogger.warning("Profile outfits fetch failed, preserving existing", category: .profile) }

        if let fetched = try? await s { savedOutfits = fetched }
        else { AppLogger.warning("Saved outfits fetch failed, preserving existing", category: .profile) }

        if let fetched = try? await e { challengeEntries = fetched }
        else { AppLogger.warning("Challenge entries fetch failed, preserving existing", category: .profile) }

        AppLogger.info("Profile load completed", category: .profile, properties: ["outfits": "\(outfits.count)", "saved": "\(savedOutfits.count)", "challenges": "\(challengeEntries.count)"])
        isLoading = false
    }

    func refreshChallengeEntries() {
        Task {
            if let entries = try? await SupabaseService.shared.fetchUserChallengeEntries(userId: user.id) {
                challengeEntries = entries
            }
        }
    }

    func deleteChallengeEntry(_ entry: ChallengeEntry) {
        GazeHaptics.medium()
        challengeEntries.removeAll { $0.id == entry.id }
        Task {
            do {
                try await SupabaseService.shared.deleteChallengeEntry(entryId: entry.id)
                NotificationCenter.default.post(name: .gazeChallengeEntryDeleted, object: entry.id)
            } catch {
                challengeEntries.insert(entry, at: 0)
            }
        }
    }

    func followToggle(for targetUser: GazeUser) -> GazeUser {
        guard let currentUserId = SupabaseManager.shared.currentUserId else { return targetUser }
        var updated = targetUser
        let wasFollowing = updated.isFollowing
        if wasFollowing {
            updated.isFollowing = false
            updated.followerCount -= 1
        } else {
            updated.isFollowing = true
            updated.followerCount += 1
        }
        GazeHaptics.medium()
        AppLogger.info("Follow toggle", category: .social, properties: ["target": targetUser.id.uuidString, "action": wasFollowing ? "unfollow" : "follow"])
        Task {
            do {
                if wasFollowing {
                    try await SupabaseService.shared.unfollow(followerId: currentUserId, followingId: targetUser.id)
                } else {
                    try await SupabaseService.shared.follow(followerId: currentUserId, followingId: targetUser.id)
                }
                let delta = wasFollowing ? -1 : 1
                NotificationCenter.default.post(name: .gazeFollowingCountChanged, object: delta)
            } catch {
                AppLogger.error("Follow toggle failed, triggering state refresh", category: .social, properties: ["target": targetUser.id.uuidString, "error": error.localizedDescription])
                NotificationCenter.default.post(name: .gazeFollowStateChanged, object: nil)
            }
        }
        return updated
    }

    func removeAvatar() {
        let userId = SupabaseManager.shared.currentUserId ?? user.id
        let previousURL = user.avatarURL
        MockDataService.shared.clearAvatarLocally(userId: userId)
        user.avatarURL = nil
        Task {
            do {
                try await SupabaseService.shared.updateAvatarURL(userId: userId, url: nil)
                AppLogger.info("Avatar removed", category: .profile, properties: ["user_id": userId.uuidString])
            } catch {
                AppLogger.error("Avatar removal failed, rolling back", category: .profile, properties: ["user_id": userId.uuidString, "error": error.localizedDescription])
                user.avatarURL = previousURL
            }
        }
    }

    func uploadAvatar(_ image: UIImage) {
        let userId = SupabaseManager.shared.currentUserId ?? user.id
        let previousURL = user.avatarURL
        AppLogger.info("Avatar upload started", category: .profile, properties: ["user_id": userId.uuidString])
        MockDataService.shared.saveAvatarLocally(image, userId: userId)
        user.avatarURL = "local://\(userId)"
        let capturedId = userId
        Task {
            do {
                let url = try await StorageService.shared.uploadAvatar(image: image, userId: capturedId)
                user.avatarURL = url
                try await SupabaseService.shared.updateAvatarURL(userId: capturedId, url: url)
                AppLogger.info("Avatar uploaded and persisted", category: .profile, properties: ["user_id": capturedId.uuidString])
            } catch {
                AppLogger.error("Avatar upload failed, rolling back", category: .profile, properties: ["user_id": capturedId.uuidString, "error": error.localizedDescription])
                MockDataService.shared.clearAvatarLocally(userId: capturedId)
                user.avatarURL = previousURL
                showAvatarUploadError = true
            }
        }
    }

    func deleteOutfit(_ outfit: Outfit) {
        GazeHaptics.medium()
        AppLogger.info("Deleting outfit", category: .post, properties: ["outfit_id": outfit.id.uuidString])
        outfits.removeAll { $0.id == outfit.id }
        Task {
            do {
                try await SupabaseService.shared.softDeleteOutfit(id: outfit.id)
                NotificationCenter.default.post(name: .gazeOutfitDeleted, object: outfit.id)
                AppLogger.info("Outfit deleted", category: .post, properties: ["outfit_id": outfit.id.uuidString])
            } catch {
                AppLogger.error("Outfit delete failed, rolling back", category: .post, properties: ["outfit_id": outfit.id.uuidString, "error": error.localizedDescription])
                outfits.insert(outfit, at: 0)
            }
        }
    }

    func updateProfile(displayName: String, bio: String, city: String, category: StyleCategory) async -> Bool {
        let oldDisplayName = user.displayName
        let oldBio = user.bio
        let oldCity = user.city
        let oldCategory = user.styleCategory

        user.displayName   = displayName
        user.bio           = bio
        user.city          = city
        user.styleCategory = category

        do {
            try await SupabaseService.shared.updateProfile(
                id: user.id, displayName: displayName, bio: bio,
                city: city, styleCategory: category)
            GazeHaptics.success()
            AppLogger.info("Profile updated", category: .profile, properties: ["user_id": user.id.uuidString])
            return true
        } catch {
            AppLogger.error("Profile update persistence failed, rolling back", category: .profile, properties: ["user_id": user.id.uuidString, "error": error.localizedDescription])
            user.displayName   = oldDisplayName
            user.bio           = oldBio
            user.city          = oldCity
            user.styleCategory = oldCategory
            return false
        }
    }
}
