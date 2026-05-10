import Foundation
import Supabase

// MARK: - Gaze Error

enum GazeError: LocalizedError {
    case authFailed
    case uploadFailed
    case profileNotFound
    case outfitDeleteFailed
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .authFailed:        return "Authentication failed. Please try again."
        case .uploadFailed:      return "Photo upload failed. Please try again."
        case .profileNotFound:   return "Profile not found."
        case .outfitDeleteFailed:
            return "Could not delete this post. It may have already been removed, or try again."
        case .unknown(let msg):  return msg
        }
    }
}

// MARK: - Supabase Service

@MainActor
final class SupabaseService {

    static let shared = SupabaseService()
    private let sb = SupabaseManager.shared.client
    private init() {}

    // MARK: - Auth

    func signUp(email: String, password: String) async throws -> UUID {
        AppLogger.info("Sign-up requested", category: .auth)
        do {
            let response = try await sb.auth.signUp(email: email, password: password)
            AppLogger.info("Sign-up succeeded", category: .auth, properties: ["user_id": response.user.id.uuidString])
            return response.user.id
        } catch {
            AppLogger.error("Sign-up failed", category: .auth, properties: ["error": error.localizedDescription])
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        AppLogger.info("Sign-in requested", category: .auth)
        do {
            try await sb.auth.signIn(email: email, password: password)
            AppLogger.info("Sign-in succeeded", category: .auth)
        } catch {
            AppLogger.error("Sign-in failed", category: .auth, properties: ["error": error.localizedDescription])
            throw error
        }
    }

    func signOut() async throws {
        AppLogger.info("Sign-out requested", category: .auth)
        try await sb.auth.signOut()
        clearBlockedUserIdsCache()
        AppLogger.info("Sign-out completed", category: .auth)
    }

    func resetPassword(email: String) async throws {
        AppLogger.info("Password reset requested", category: .auth)
        do {
            try await sb.auth.resetPasswordForEmail(email)
            AppLogger.info("Password reset email sent", category: .auth)
        } catch {
            AppLogger.error("Password reset failed", category: .auth, properties: ["error": error.localizedDescription])
            throw error
        }
    }

    func currentSession() -> Session? {
        let session = sb.auth.currentSession
        AppLogger.debug("Session check | has_session=\(session != nil)", category: .auth)
        return session
    }

    /// Session suitable for routing after cold start: loads stored session, and if it is expired
    /// (or within the SDK expiry margin), refreshes once. Clears auth state if refresh fails.
    func sessionForAppRouting() async -> Session? {
        guard let session = sb.auth.currentSession else {
            AppLogger.debug("Session check | has_session=false", category: .auth)
            return nil
        }
        if session.isExpired {
            AppLogger.info("Stored session expired at launch, refreshing", category: .auth)
            do {
                let refreshed = try await sb.auth.refreshSession()
                AppLogger.info("Session refreshed at launch", category: .auth)
                return refreshed
            } catch {
                AppLogger.warning(
                    "Session refresh failed at launch, clearing auth",
                    category: .auth,
                    properties: ["error": error.localizedDescription]
                )
                try? await sb.auth.signOut()
                clearBlockedUserIdsCache()
                return nil
            }
        }
        AppLogger.debug("Session check | has_session=true", category: .auth)
        return session
    }

    // MARK: - Profile

    func createProfile(id: UUID, username: String, displayName: String,
                       city: String, styleCategory: StyleCategory) async throws {
        struct NewProfile: Encodable {
            let id: UUID
            let username: String
            let display_name: String
            let city: String
            let style_category: String
        }
        AppLogger.info("Creating profile", category: .profile, properties: ["user_id": id.uuidString])
        do {
            try await sb.from("profiles")
                .upsert(NewProfile(id: id, username: username, display_name: displayName,
                                   city: city, style_category: styleCategory.rawValue))
                .execute()
            AppLogger.info("Profile created", category: .profile, properties: ["user_id": id.uuidString])
        } catch {
            AppLogger.error("Profile creation failed", category: .profile, properties: ["user_id": id.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    func fetchProfile(id: UUID) async throws -> DBProfile {
        AppLogger.debug("Fetching profile", category: .profile, properties: ["user_id": id.uuidString])
        do {
            let profile: DBProfile = try await sb.from("profiles")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            AppLogger.debug("Profile fetched", category: .profile, properties: ["user_id": id.uuidString])
            return profile
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            AppLogger.error("Profile fetch failed", category: .profile, properties: ["user_id": id.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    func fetchProfile(username: String) async throws -> DBProfile {
        try await sb.from("profiles")
            .select()
            .eq("username", value: username)
            .single()
            .execute()
            .value
    }

    func isUsernameTaken(_ username: String) async throws -> Bool {
        let result: [DBProfile] = try await sb.from("profiles")
            .select("id")
            .eq("username", value: username)
            .execute()
            .value
        return !result.isEmpty
    }

    func updateProfile(id: UUID, displayName: String, bio: String,
                       city: String, styleCategory: StyleCategory) async throws {
        struct ProfileUpdate: Encodable {
            let display_name: String
            let bio: String
            let city: String
            let style_category: String
        }
        AppLogger.info("Updating profile", category: .profile, properties: ["user_id": id.uuidString])
        do {
            try await sb.from("profiles")
                .update(ProfileUpdate(display_name: displayName, bio: bio,
                                      city: city, style_category: styleCategory.rawValue))
                .eq("id", value: id)
                .execute()
            AppLogger.info("Profile updated", category: .profile, properties: ["user_id": id.uuidString])
        } catch {
            AppLogger.error("Profile update failed", category: .profile, properties: ["user_id": id.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    func updateAvatarURL(userId: UUID, url: String?) async throws {
        struct AvatarUpdate: Encodable { let avatar_url: String? }
        AppLogger.info("Updating avatar URL", category: .profile, properties: ["user_id": userId.uuidString, "has_url": "\(url != nil)"])
        try await sb.from("profiles")
            .update(AvatarUpdate(avatar_url: url))
            .eq("id", value: userId)
            .execute()
    }

    private func filterBlocked(_ outfits: [Outfit]) -> [Outfit] {
        guard !blockedUserIdsCache.isEmpty else { return outfits }
        return outfits.filter { !blockedUserIdsCache.contains($0.userId) }
    }

    // MARK: - Feed (mutual follows only)

    func fetchFeed(currentUserId: UUID, limit: Int = 20, offset: Int = 0) async throws -> [Outfit] {
        AppLogger.debug("Fetching friends feed", category: .feed, properties: ["limit": "\(limit)", "offset": "\(offset)"])
        async let followingReq: [DBFollow] = sb.from("follows")
            .select("id, follower_id, following_id")
            .eq("follower_id", value: currentUserId)
            .execute()
            .value
        async let followersReq: [DBFollow] = sb.from("follows")
            .select("id, follower_id, following_id")
            .eq("following_id", value: currentUserId)
            .execute()
            .value

        let (following, followers) = try await (followingReq, followersReq)
        let followingIds = Set(following.map { $0.followingId })
        let followerIds  = Set(followers.map { $0.followerId })
        let mutualIds    = followingIds.intersection(followerIds)

        var feedUserIds = Array(mutualIds)
        feedUserIds.append(currentUserId)
        AppLogger.debug("Friends feed query", category: .feed, properties: ["mutual_count": "\(mutualIds.count)", "feed_user_count": "\(feedUserIds.count)"])

        let dbOutfits: [DBOutfit] = try await sb.from("outfits")
            .select("*, profiles(*)")
            .in("user_id", values: feedUserIds)
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        let displayedIds = dbOutfits.map { $0.id }
        async let firedReq = fetchUserFireIds(userId: currentUserId, outfitIds: displayedIds)
        async let savedReq = fetchUserSaveIds(userId: currentUserId, outfitIds: displayedIds)
        let (firedIds, savedIds) = try await (firedReq, savedReq)

        let result = filterBlocked(dbOutfits.map {
            $0.toOutfit(firedByCurrentUser: firedIds.contains($0.id),
                        savedByCurrentUser: savedIds.contains($0.id))
        })
        AppLogger.info("Friends feed loaded", category: .feed, properties: ["count": "\(result.count)"])
        if result.isEmpty {
            AppLogger.warning("Friends feed returned empty", category: .feed)
        }
        return result
    }

    // MARK: - Feed (everyone I follow, "everyone"-visibility posts only)

    func fetchFollowingFeed(currentUserId: UUID, limit: Int = 30, offset: Int = 0) async throws -> [Outfit] {
        AppLogger.debug("Fetching following feed", category: .feed, properties: ["limit": "\(limit)", "offset": "\(offset)"])
        let following: [DBFollow] = try await sb.from("follows")
            .select("id, follower_id, following_id")
            .eq("follower_id", value: currentUserId)
            .execute()
            .value

        var feedUserIds = following.map { $0.followingId }
        feedUserIds.append(currentUserId)

        let dbOutfits: [DBOutfit] = try await sb.from("outfits")
            .select("*, profiles(*)")
            .in("user_id", values: feedUserIds)
            .eq("visibility", value: "everyone")
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        let displayedIds = dbOutfits.map { $0.id }
        async let firedReq = fetchUserFireIds(userId: currentUserId, outfitIds: displayedIds)
        async let savedReq = fetchUserSaveIds(userId: currentUserId, outfitIds: displayedIds)
        let (firedIds, savedIds) = try await (firedReq, savedReq)
        let result = filterBlocked(dbOutfits.map {
            $0.toOutfit(firedByCurrentUser: firedIds.contains($0.id),
                        savedByCurrentUser: savedIds.contains($0.id))
        })
        AppLogger.info("Following feed loaded", category: .feed, properties: ["count": "\(result.count)", "following_count": "\(following.count)"])
        return result
    }

    // MARK: - Trending

    func fetchTrending(currentUserId: UUID?, limit: Int = 40) async throws -> [Outfit] {
        let rows: [DBOutfit] = try await sb.from("outfits")
            .select("*, profiles(*)")
            .eq("visibility", value: "everyone")
            .is("deleted_at", value: nil)
            .order("fire_count", ascending: false)
            .limit(limit)
            .execute()
            .value
        if let userId = currentUserId {
            let displayedIds = rows.map { $0.id }
            async let firedReq = fetchUserFireIds(userId: userId, outfitIds: displayedIds)
            async let savedReq = fetchUserSaveIds(userId: userId, outfitIds: displayedIds)
            let (firedIds, savedIds) = try await (firedReq, savedReq)
            return filterBlocked(rows.map { $0.toOutfit(firedByCurrentUser: firedIds.contains($0.id),
                                          savedByCurrentUser: savedIds.contains($0.id)) })
        }
        return filterBlocked(rows.map { $0.toOutfit() })
    }

    // MARK: - Profile outfits

    func fetchProfileOutfits(userId: UUID, currentUserId: UUID) async throws -> [Outfit] {
        let dbOutfits: [DBOutfit] = try await sb.from("outfits")
            .select("*, profiles(*)")
            .eq("user_id", value: userId)
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value

        let displayedIds = dbOutfits.map { $0.id }
        async let firedReq  = fetchUserFireIds(userId: currentUserId, outfitIds: displayedIds)
        async let savedReq  = fetchUserSaveIds(userId: currentUserId, outfitIds: displayedIds)
        let (firedIds, savedIds) = try await (firedReq, savedReq)
        return dbOutfits.map { $0.toOutfit(firedByCurrentUser: firedIds.contains($0.id),
                                           savedByCurrentUser: savedIds.contains($0.id)) }
    }

    func fetchSavedOutfits(userId: UUID) async throws -> [Outfit] {
        let result: [DBSavedJoin] = try await sb.from("saved_outfits")
            .select("outfits(*, profiles(*))")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        let active = result.filter { $0.outfits.deletedAt == nil }
        let outfitIds = active.map { $0.outfits.id }
        let firedIds = try await fetchUserFireIds(userId: userId, outfitIds: outfitIds)
        return active.map { $0.outfits.toOutfit(firedByCurrentUser: firedIds.contains($0.outfits.id),
                                                savedByCurrentUser: true) }
    }

    // MARK: - Post outfit

    /// Trims and adds `https://` when no scheme is present. Returns `nil` if empty after trim.
    static func normalizedOutfitLinkForStorage(_ raw: String?) -> String? {
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !t.isEmpty else { return nil }
        let lower = t.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return t }
        return "https://\(t)"
    }

    func insertOutfit(userId: UUID, gradientIndex: Int = 0, imageUrl: String? = nil,
                      caption: String, brands: [String], category: StyleCategory,
                      priceLevel: PriceLevel = .mid, city: String = "",
                      visibility: PostVisibility, productLink: String? = nil) async throws -> Outfit {
        struct NewOutfit: Encodable {
            let user_id: UUID
            let image_url: String?
            let caption: String
            let brands: [String]
            let style_category: String
            let price_level: Int
            let visibility: String
            let link: String?
        }
        let linkToStore = Self.normalizedOutfitLinkForStorage(productLink)
        AppLogger.info("Inserting outfit", category: .post, properties: ["user_id": userId.uuidString, "has_image": "\(imageUrl != nil)", "visibility": visibility.rawValue])
        do {
            let inserted: DBOutfit = try await sb.from("outfits")
                .insert(NewOutfit(user_id: userId, image_url: imageUrl, caption: caption,
                                  brands: brands, style_category: category.rawValue,
                                  price_level: priceLevel.rawValue,
                                  visibility: visibility.rawValue,
                                  link: linkToStore))
                .select("*, profiles(*)")
                .single()
                .execute()
                .value
            var outfit = inserted.toOutfit()
            outfit.gradientIndex = gradientIndex
            AppLogger.info("Outfit inserted", category: .post, properties: ["outfit_id": outfit.id.uuidString])
            return outfit
        } catch {
            AppLogger.error("Outfit insert failed", category: .post, properties: ["user_id": userId.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    func softDeleteOutfit(id: UUID) async throws {
        struct DeleteUpdate: Encodable { let deleted_at: Date }
        struct IdRow: Decodable { let id: UUID }
        AppLogger.info("Soft-deleting outfit", category: .post, properties: ["outfit_id": id.uuidString])
        do {
            let updated: [IdRow] = try await sb.from("outfits")
                .update(DeleteUpdate(deleted_at: Date()))
                .eq("id", value: id)
                .select("id")
                .execute()
                .value
            guard !updated.isEmpty else {
                AppLogger.error("Outfit soft-delete affected 0 rows (RLS or missing row)", category: .post, properties: ["outfit_id": id.uuidString])
                throw GazeError.outfitDeleteFailed
            }
            AppLogger.info("Outfit soft-deleted", category: .post, properties: ["outfit_id": id.uuidString])
        } catch let gaze as GazeError {
            throw gaze
        } catch {
            AppLogger.error("Outfit soft-delete failed", category: .post, properties: ["outfit_id": id.uuidString, "error": error.localizedDescription])
            throw error
        }
        if let userId = SupabaseManager.shared.currentUserId {
            await decrementProfileOutfitCount(userId: userId)
        }
    }

    private func decrementProfileOutfitCount(userId: UUID) async {
        struct CountRow: Decodable {
            let outfitCount: Int
            enum CodingKeys: String, CodingKey { case outfitCount = "outfit_count" }
        }
        struct CountUpdate: Encodable { let outfit_count: Int }
        do {
            let rows: [CountRow] = try await sb.from("profiles")
                .select("outfit_count")
                .eq("id", value: userId)
                .execute()
                .value
            guard let current = rows.first else { return }
            let newCount = max(0, current.outfitCount - 1)
            try await sb.from("profiles")
                .update(CountUpdate(outfit_count: newCount))
                .eq("id", value: userId)
                .execute()
            AppLogger.info("outfit_count decremented", category: .post, properties: ["user_id": userId.uuidString, "new_count": "\(newCount)"])
        } catch {
            AppLogger.error("outfit_count decrement failed", category: .post, properties: ["user_id": userId.uuidString, "error": error.localizedDescription])
        }
    }

    // MARK: - Fires

    private func fetchUserFireIds(userId: UUID, outfitIds: [UUID] = []) async throws -> Set<UUID> {
        struct Row: Decodable {
            let outfitId: UUID
            enum CodingKeys: String, CodingKey { case outfitId = "outfit_id" }
        }
        let rows: [Row]
        if !outfitIds.isEmpty {
            rows = try await sb.from("fires")
                .select("outfit_id")
                .eq("user_id", value: userId)
                .in("outfit_id", values: outfitIds)
                .execute()
                .value
        } else {
            rows = try await sb.from("fires")
                .select("outfit_id")
                .eq("user_id", value: userId)
                .limit(1000)
                .execute()
                .value
        }
        return Set(rows.map { $0.outfitId })
    }

    func addFire(outfitId: UUID, userId: UUID) async throws {
        try await sb.from("fires")
            .upsert(
                ["outfit_id": outfitId.uuidString, "user_id": userId.uuidString],
                onConflict: "outfit_id,user_id",
                ignoreDuplicates: true
            )
            .execute()
        // fire_count is updated by a DB trigger on the fires table
    }

    func removeFire(outfitId: UUID, userId: UUID) async throws {
        try await sb.from("fires")
            .delete()
            .eq("outfit_id", value: outfitId)
            .eq("user_id", value: userId)
            .execute()
        // fire_count is updated by a DB trigger on the fires table
    }

    // MARK: - Saves

    private func fetchUserSaveIds(userId: UUID, outfitIds: [UUID] = []) async throws -> Set<UUID> {
        struct Row: Decodable {
            let outfitId: UUID
            enum CodingKeys: String, CodingKey { case outfitId = "outfit_id" }
        }
        let rows: [Row]
        if !outfitIds.isEmpty {
            rows = try await sb.from("saved_outfits")
                .select("outfit_id")
                .eq("user_id", value: userId)
                .in("outfit_id", values: outfitIds)
                .execute()
                .value
        } else {
            rows = try await sb.from("saved_outfits")
                .select("outfit_id")
                .eq("user_id", value: userId)
                .limit(1000)
                .execute()
                .value
        }
        return Set(rows.map { $0.outfitId })
    }

    func saveOutfit(outfitId: UUID, userId: UUID) async throws {
        struct NewSave: Encodable { let outfit_id: UUID; let user_id: UUID }
        try await sb.from("saved_outfits")
            .insert(NewSave(outfit_id: outfitId, user_id: userId))
            .execute()
    }

    func unsaveOutfit(outfitId: UUID, userId: UUID) async throws {
        try await sb.from("saved_outfits")
            .delete()
            .eq("outfit_id", value: outfitId)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Follows

    func follow(followerId: UUID, followingId: UUID) async throws {
        AppLogger.info("Follow requested", category: .social, properties: ["follower": followerId.uuidString, "following": followingId.uuidString])
        do {
            try await sb.from("follows")
                .upsert(
                    ["follower_id": followerId.uuidString, "following_id": followingId.uuidString],
                    onConflict: "follower_id,following_id",
                    ignoreDuplicates: true
                )
                .execute()
            AppLogger.info("Follow succeeded", category: .social, properties: ["follower": followerId.uuidString, "following": followingId.uuidString])
        } catch {
            AppLogger.error("Follow failed", category: .social, properties: ["follower": followerId.uuidString, "following": followingId.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    func unfollow(followerId: UUID, followingId: UUID) async throws {
        AppLogger.info("Unfollow requested", category: .social, properties: ["follower": followerId.uuidString, "following": followingId.uuidString])
        do {
            try await sb.from("follows")
                .delete()
                .eq("follower_id", value: followerId)
                .eq("following_id", value: followingId)
                .execute()
            AppLogger.info("Unfollow succeeded", category: .social, properties: ["follower": followerId.uuidString, "following": followingId.uuidString])
        } catch {
            AppLogger.error("Unfollow failed", category: .social, properties: ["follower": followerId.uuidString, "following": followingId.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    func isFollowing(followerId: UUID, followingId: UUID) async throws -> Bool {
        let result: [DBFollow] = try await sb.from("follows")
            .select("id, follower_id, following_id")
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .execute()
            .value
        return !result.isEmpty
    }

    // MARK: - Post Limit

    func fetchTodayPostCount(userId: UUID) async throws -> Int {
        struct Row: Decodable { let id: UUID }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let rows: [Row] = try await sb.from("outfits")
            .select("id")
            .eq("user_id", value: userId)
            .is("deleted_at", value: nil)
            .gte("created_at", value: iso.string(from: startOfDay))
            .execute()
            .value
        return rows.count
    }

    // MARK: - Comments

    func fetchComments(outfitId: UUID, currentUserId: UUID? = nil) async throws -> [Comment] {
        let rows: [DBComment] = try await sb.from("comments")
            .select("*, profiles(*)")
            .eq("outfit_id", value: outfitId)
            .order("created_at", ascending: true)
            .limit(200)
            .execute()
            .value
        if let userId = currentUserId, !rows.isEmpty {
            let likedIds = (try? await fetchLikedCommentIds(commentIds: rows.map { $0.id }, userId: userId)) ?? []
            return rows.map { $0.toComment(isLiked: likedIds.contains($0.id)) }
        }
        return rows.map { $0.toComment() }
    }

    func addComment(outfitId: UUID, userId: UUID, text: String) async throws -> Comment {
        struct NewComment: Encodable { let outfit_id: UUID; let user_id: UUID; let text: String }
        AppLogger.info("Posting comment", category: .comments, properties: ["outfit_id": outfitId.uuidString, "user_id": userId.uuidString])
        do {
            let row: DBComment = try await sb.from("comments")
                .insert(NewComment(outfit_id: outfitId, user_id: userId, text: text))
                .select("*, profiles(*)")
                .single()
                .execute()
                .value
            AppLogger.info("Comment posted", category: .comments, properties: ["comment_id": row.id.uuidString, "outfit_id": outfitId.uuidString])
            return row.toComment()
        } catch {
            AppLogger.error("Comment post failed", category: .comments, properties: ["outfit_id": outfitId.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    func deleteComment(commentId: UUID, outfitId: UUID) async throws {
        AppLogger.info("Deleting comment", category: .comments, properties: ["comment_id": commentId.uuidString, "outfit_id": outfitId.uuidString])
        do {
            try await sb.from("comments")
                .delete()
                .eq("id", value: commentId)
                .execute()
            AppLogger.info("Comment deleted", category: .comments, properties: ["comment_id": commentId.uuidString])
        } catch {
            AppLogger.error("Comment delete failed", category: .comments, properties: ["comment_id": commentId.uuidString, "error": error.localizedDescription])
            throw error
        }
        await decrementOutfitCommentCount(outfitId: outfitId)
    }

    private func decrementOutfitCommentCount(outfitId: UUID) async {
        struct CountRow: Decodable {
            let commentCount: Int
            enum CodingKeys: String, CodingKey { case commentCount = "comment_count" }
        }
        struct CountUpdate: Encodable { let comment_count: Int }
        do {
            let rows: [CountRow] = try await sb.from("outfits")
                .select("comment_count")
                .eq("id", value: outfitId)
                .execute()
                .value
            guard let current = rows.first else { return }
            let newCount = max(0, current.commentCount - 1)
            try await sb.from("outfits")
                .update(CountUpdate(comment_count: newCount))
                .eq("id", value: outfitId)
                .execute()
            AppLogger.info("comment_count decremented", category: .comments, properties: ["outfit_id": outfitId.uuidString, "new_count": "\(newCount)"])
        } catch {
            AppLogger.error("comment_count decrement failed", category: .comments, properties: ["outfit_id": outfitId.uuidString, "error": error.localizedDescription])
        }
    }

    func likeComment(commentId: UUID, userId: UUID) async throws {
        struct NewLike: Encodable { let comment_id: UUID; let user_id: UUID }
        try await sb.from("comment_likes")
            .upsert(
                NewLike(comment_id: commentId, user_id: userId),
                onConflict: "comment_id,user_id",
                ignoreDuplicates: true
            )
            .execute()
    }

    func unlikeComment(commentId: UUID, userId: UUID) async throws {
        try await sb.from("comment_likes")
            .delete()
            .eq("comment_id", value: commentId)
            .eq("user_id", value: userId)
            .execute()
    }

    func fetchLikedCommentIds(commentIds: [UUID], userId: UUID) async throws -> Set<UUID> {
        guard !commentIds.isEmpty else { return [] }
        struct Row: Decodable {
            let commentId: UUID
            enum CodingKeys: String, CodingKey { case commentId = "comment_id" }
        }
        let rows: [Row] = try await sb.from("comment_likes")
            .select("comment_id")
            .in("comment_id", values: commentIds)
            .eq("user_id", value: userId)
            .execute()
            .value
        return Set(rows.map { $0.commentId })
    }

    // MARK: - Explore

    func fetchExploreFeed(currentUserId: UUID?, limit: Int = 50, offset: Int = 0) async throws -> [Outfit] {
        let rows: [DBOutfit] = try await sb.from("outfits")
            .select("*, profiles(*)")
            .eq("visibility", value: "everyone")
            .is("deleted_at", value: nil)
            .order("fire_count", ascending: false)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        if let userId = currentUserId {
            let displayedIds = rows.map { $0.id }
            async let firedReq = fetchUserFireIds(userId: userId, outfitIds: displayedIds)
            async let savedReq = fetchUserSaveIds(userId: userId, outfitIds: displayedIds)
            let (firedIds, savedIds) = try await (firedReq, savedReq)
            return filterBlocked(rows.map { $0.toOutfit(firedByCurrentUser: firedIds.contains($0.id),
                                          savedByCurrentUser: savedIds.contains($0.id)) })
        }
        return filterBlocked(rows.map { $0.toOutfit() })
    }

    func searchUsers(query: String) async throws -> [GazeUser] {
        let profiles: [DBProfile] = try await sb.from("profiles")
            .select()
            .ilike("username", pattern: "%\(query)%")
            .limit(20)
            .execute()
            .value
        let users = profiles.map { $0.toGazeUser() }
        guard !blockedUserIdsCache.isEmpty else { return users }
        return users.filter { !blockedUserIdsCache.contains($0.id) }
    }

    // MARK: - Rankings

    func fetchRankings(scope: RankingScope, city: String?) async throws -> [RankingEntry] {
        struct RankingRow: Decodable {
            let userId: UUID
            let username: String
            let displayName: String
            let avatarUrl: String?
            let bio: String
            let city: String
            let styleCategory: String
            let followerCount: Int
            let followingCount: Int
            let outfitCount: Int
            let isVerified: Bool
            let challengeWins: Int
            let totalFires: Int
            let rank: Int

            enum CodingKeys: String, CodingKey {
                case username, bio, city, rank
                case userId        = "user_id"
                case displayName   = "display_name"
                case avatarUrl     = "avatar_url"
                case styleCategory = "style_category"
                case followerCount = "follower_count"
                case followingCount = "following_count"
                case outfitCount   = "outfit_count"
                case isVerified    = "is_verified"
                case challengeWins = "challenge_wins"
                case totalFires    = "total_fires"
            }
        }

        var params: [String: String] = [
            "scope": scope == .city ? "city" : "global",
            "result_limit": "50"
        ]
        if scope == .city, let city, !city.isEmpty {
            params["filter_city"] = city
        }

        let rows: [RankingRow] = try await sb.rpc("get_rankings", params: params)
            .execute()
            .value

        let palette = ["#2d1b69","#0a0a0a","#c94b4b","#b8860b","#5856D6",
                       "#8A8A8A","#FF9500","#636366","#6C6C70","#00C7BE"]

        return rows.map { row in
            let user = GazeUser(
                id: row.userId,
                username: row.username,
                displayName: row.displayName.isEmpty ? row.username : row.displayName,
                avatarColorHex: palette[abs(row.userId.hashValue) % palette.count],
                city: row.city,
                bio: row.bio,
                styleScore: min(Double(row.totalFires) / 10.0, 10.0),
                styleCategory: StyleCategory(rawValue: row.styleCategory) ?? .minimalist,
                followerCount: row.followerCount,
                followingCount: row.followingCount,
                outfitCount: row.outfitCount,
                isVerified: row.isVerified,
                isFollowing: false,
                gradientIndex: abs(row.userId.hashValue) % 20,
                avatarURL: row.avatarUrl,
                challengeWins: row.challengeWins
            )
            return RankingEntry(
                id: row.userId,
                user: user,
                rank: row.rank,
                score: min(Double(row.totalFires) / 10.0, 10.0),
                rankChange: 0,
                weeklyFires: row.totalFires,
                totalRatings: row.totalFires
            )
        }
    }

    // MARK: - Notifications

    func fetchNotifications(userId: UUID) async throws -> [GazeNotification] {
        let rows: [DBNotification] = try await sb.from("notifications")
            .select("*, from_profile:profiles!from_user_id(*)")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        let notifications = rows.compactMap { $0.toGazeNotification() }
        guard !blockedUserIdsCache.isEmpty else { return notifications }
        return notifications.filter { !blockedUserIdsCache.contains($0.fromUser.id) }
    }

    func markNotificationRead(id: UUID) async throws {
        struct Update: Encodable { let is_read: Bool }
        try await sb.from("notifications")
            .update(Update(is_read: true))
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Friend Requests

    func sendFriendRequest(fromUserId: UUID, toUserId: UUID) async throws {
        AppLogger.info("Sending friend request", category: .social, properties: ["from": fromUserId.uuidString, "to": toUserId.uuidString])
        _ = try? await sb.from("friend_requests")
            .delete()
            .eq("from_user_id", value: fromUserId)
            .eq("to_user_id", value: toUserId)
            .execute()
        struct NewRequest: Encodable { let from_user_id: UUID; let to_user_id: UUID }
        do {
            try await sb.from("friend_requests")
                .insert(NewRequest(from_user_id: fromUserId, to_user_id: toUserId))
                .execute()
            AppLogger.info("Friend request sent", category: .social, properties: ["from": fromUserId.uuidString, "to": toUserId.uuidString])
        } catch {
            AppLogger.error("Friend request send failed", category: .social, properties: ["from": fromUserId.uuidString, "to": toUserId.uuidString, "error": error.localizedDescription])
            throw error
        }
        _ = try? await sb.from("notifications")
            .delete()
            .eq("type", value: "friend_request")
            .eq("from_user_id", value: fromUserId)
            .eq("user_id", value: toUserId)
            .execute()
        struct NewNotif: Encodable {
            let type: String; let from_user_id: UUID; let user_id: UUID; let message: String
        }
        _ = try? await sb.from("notifications")
            .insert(NewNotif(type: "friend_request", from_user_id: fromUserId,
                             user_id: toUserId, message: "sent you a friend request"))
            .execute()
    }

    func fetchIncomingRequests(userId: UUID) async throws -> [FriendRequest] {
        let rows: [DBFriendRequest] = try await sb.from("friend_requests")
            .select("*, from_profile:profiles!from_user_id(*)")
            .eq("to_user_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.compactMap { $0.toFriendRequest() }
    }

    func fetchSentPendingIds(fromUserId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable {
            let toUserId: UUID
            enum CodingKeys: String, CodingKey { case toUserId = "to_user_id" }
        }
        let rows: [Row] = try await sb.from("friend_requests")
            .select("to_user_id")
            .eq("from_user_id", value: fromUserId)
            .eq("status", value: "pending")
            .execute()
            .value
        return Set(rows.map { $0.toUserId })
    }

    func acceptFriendRequest(fromUserId: UUID, toUserId: UUID) async throws {
        struct StatusUpdate: Encodable { let status: String }
        AppLogger.info("Accepting friend request", category: .social, properties: ["from": fromUserId.uuidString, "to": toUserId.uuidString])
        do {
            try await sb.from("friend_requests")
                .update(StatusUpdate(status: "accepted"))
                .eq("from_user_id", value: fromUserId)
                .eq("to_user_id", value: toUserId)
                .eq("status", value: "pending")
                .execute()

            try await follow(followerId: fromUserId, followingId: toUserId)
            try await follow(followerId: toUserId, followingId: fromUserId)
            AppLogger.info("Friend request accepted", category: .social, properties: ["from": fromUserId.uuidString, "to": toUserId.uuidString])
        } catch {
            AppLogger.error("Friend request accept failed", category: .social, properties: ["from": fromUserId.uuidString, "to": toUserId.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    func declineFriendRequest(fromUserId: UUID, toUserId: UUID) async throws {
        struct StatusUpdate: Encodable { let status: String }
        AppLogger.info("Declining friend request", category: .social, properties: ["from": fromUserId.uuidString, "to": toUserId.uuidString])
        do {
            try await sb.from("friend_requests")
                .update(StatusUpdate(status: "declined"))
                .eq("from_user_id", value: fromUserId)
                .eq("to_user_id", value: toUserId)
                .execute()
            AppLogger.info("Friend request declined", category: .social, properties: ["from": fromUserId.uuidString, "to": toUserId.uuidString])
        } catch {
            AppLogger.error("Friend request decline failed", category: .social, properties: ["from": fromUserId.uuidString, "to": toUserId.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    // MARK: - Friends (mutual follows)

    func fetchFriends(currentUserId: UUID) async throws -> [GazeUser] {
        async let followingReq: [DBFollow] = sb.from("follows")
            .select("id, follower_id, following_id")
            .eq("follower_id", value: currentUserId)
            .execute()
            .value
        async let followersReq: [DBFollow] = sb.from("follows")
            .select("id, follower_id, following_id")
            .eq("following_id", value: currentUserId)
            .execute()
            .value
        let (following, followers) = try await (followingReq, followersReq)
        let followingIds = Set(following.map { $0.followingId })
        let followerIds  = Set(followers.map { $0.followerId })
        let mutualIds    = Array(followingIds.intersection(followerIds))
        guard !mutualIds.isEmpty else { return [] }
        let profiles: [DBProfile] = try await sb.from("profiles")
            .select()
            .in("id", values: mutualIds)
            .execute()
            .value
        return profiles.map { $0.toGazeUser(isFollowing: true) }
    }

    func fetchFollowers(userId: UUID) async throws -> [GazeUser] {
        let follows: [DBFollow] = try await sb.from("follows")
            .select("id, follower_id, following_id")
            .eq("following_id", value: userId)
            .execute()
            .value
        let ids = follows.map { $0.followerId }
        guard !ids.isEmpty else { return [] }
        let profiles: [DBProfile] = try await sb.from("profiles")
            .select()
            .in("id", values: ids)
            .execute()
            .value
        return profiles.map { $0.toGazeUser() }
    }

    func fetchFollowing(userId: UUID) async throws -> [GazeUser] {
        let follows: [DBFollow] = try await sb.from("follows")
            .select("id, follower_id, following_id")
            .eq("follower_id", value: userId)
            .execute()
            .value
        let ids = follows.map { $0.followingId }
        guard !ids.isEmpty else { return [] }
        let profiles: [DBProfile] = try await sb.from("profiles")
            .select()
            .in("id", values: ids)
            .execute()
            .value
        return profiles.map { $0.toGazeUser() }
    }

    // MARK: - Blocked Users

    private var blockedUserIdsCache: Set<UUID> = []

    func fetchBlockedUserIds(userId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable {
            let blockedId: UUID
            enum CodingKeys: String, CodingKey { case blockedId = "blocked_id" }
        }
        let rows: [Row] = try await sb.from("blocked_users")
            .select("blocked_id")
            .eq("blocker_id", value: userId)
            .execute()
            .value
        let ids = Set(rows.map { $0.blockedId })
        blockedUserIdsCache = ids
        return ids
    }

    func fetchBlockedUsers(userId: UUID) async throws -> [GazeUser] {
        let blockedIds = try await fetchBlockedUserIds(userId: userId)
        let ids = Array(blockedIds)
        guard !ids.isEmpty else { return [] }
        let profiles: [DBProfile] = try await sb.from("profiles")
            .select()
            .in("id", values: ids)
            .execute()
            .value
        return profiles.map { $0.toGazeUser() }
    }

    func blockUser(blockerId: UUID, blockedId: UUID) async throws {
        struct NewBlock: Encodable { let blocker_id: UUID; let blocked_id: UUID }
        AppLogger.info("Blocking user", category: .social, properties: ["blocker": blockerId.uuidString, "blocked": blockedId.uuidString])
        do {
            try await sb.from("blocked_users")
                .upsert(
                    NewBlock(blocker_id: blockerId, blocked_id: blockedId),
                    onConflict: "blocker_id,blocked_id",
                    ignoreDuplicates: true
                )
                .execute()
            blockedUserIdsCache.insert(blockedId)

            do {
                try await sb.from("follows")
                    .delete()
                    .eq("follower_id", value: blockerId)
                    .eq("following_id", value: blockedId)
                    .execute()
            } catch {
                AppLogger.warning("Block follow cleanup (blocker→blocked) failed", category: .social, properties: ["error": error.localizedDescription])
            }
            do {
                try await sb.from("follows")
                    .delete()
                    .eq("follower_id", value: blockedId)
                    .eq("following_id", value: blockerId)
                    .execute()
            } catch {
                AppLogger.warning("Block follow cleanup (blocked→blocker) failed", category: .social, properties: ["error": error.localizedDescription])
            }
            AppLogger.info("User blocked + mutual follows removed", category: .social, properties: ["blocker": blockerId.uuidString, "blocked": blockedId.uuidString])
        } catch {
            AppLogger.error("Block user failed", category: .social, properties: ["blocker": blockerId.uuidString, "blocked": blockedId.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    func unblockUser(blockerId: UUID, blockedId: UUID) async throws {
        AppLogger.info("Unblocking user", category: .social, properties: ["blocker": blockerId.uuidString, "blocked": blockedId.uuidString])
        do {
            try await sb.from("blocked_users")
                .delete()
                .eq("blocker_id", value: blockerId)
                .eq("blocked_id", value: blockedId)
                .execute()
            blockedUserIdsCache.remove(blockedId)
            AppLogger.info("User unblocked", category: .social, properties: ["blocker": blockerId.uuidString, "blocked": blockedId.uuidString])
        } catch {
            AppLogger.error("Unblock user failed", category: .social, properties: ["blocker": blockerId.uuidString, "blocked": blockedId.uuidString, "error": error.localizedDescription])
            throw error
        }
    }

    func isBlocked(blockerId: UUID, blockedId: UUID) -> Bool {
        blockedUserIdsCache.contains(blockedId)
    }

    func refreshBlockedCache(userId: UUID) async {
        _ = try? await fetchBlockedUserIds(userId: userId)
    }

    /// Clears in-memory blocked-user IDs so a new session never inherits another account's block list.
    func clearBlockedUserIdsCache() {
        blockedUserIdsCache = []
        AppLogger.debug("Blocked-user cache cleared", category: .social)
    }

    // MARK: - Weekly Challenge

    func fetchChallengeEntries(weekNumber: Int, year: Int, currentUserId: UUID) async throws -> (entries: [ChallengeEntry], myEntryId: UUID?, votedEntryId: UUID?) {
        let rows: [DBChallengeEntry] = try await sb.from("challenge_entries")
            .select("*, outfits(*, profiles(*))")
            .eq("week_number", value: weekNumber)
            .eq("year", value: year)
            .order("vote_count", ascending: false)
            .execute()
            .value

        let myEntryId = rows.first(where: { $0.userId == currentUserId })?.id

        struct VoteRow: Codable {
            let entryId: UUID
            enum CodingKeys: String, CodingKey { case entryId = "entry_id" }
        }
        let votes: [VoteRow] = try await sb.from("challenge_votes")
            .select("entry_id")
            .eq("week_number", value: weekNumber)
            .eq("year", value: year)
            .eq("voter_id", value: currentUserId)
            .execute()
            .value
        let votedEntryId = votes.first?.entryId

        let entries = rows.map { $0.toChallengeEntry(hasVoted: $0.id == votedEntryId) }
        return (entries, myEntryId, votedEntryId)
    }

    func submitChallengeEntry(weekNumber: Int, year: Int, userId: UUID, outfitId: UUID) async throws {
        struct InsertRow: Codable {
            let weekNumber: Int; let year: Int; let userId: UUID; let outfitId: UUID
            enum CodingKeys: String, CodingKey {
                case weekNumber = "week_number"; case year
                case userId = "user_id"; case outfitId = "outfit_id"
            }
        }
        _ = try await sb.from("challenge_entries")
            .insert(InsertRow(weekNumber: weekNumber, year: year, userId: userId, outfitId: outfitId))
            .execute()
    }

    func deleteChallengeEntry(entryId: UUID) async throws {
        _ = try await sb.from("challenge_entries")
            .delete()
            .eq("id", value: entryId)
            .execute()
    }

    func fetchUserChallengeEntries(userId: UUID) async throws -> [ChallengeEntry] {
        let rows: [DBChallengeEntry] = try await sb.from("challenge_entries")
            .select("*, outfits(*, profiles(*))")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toChallengeEntry() }
    }

    func voteChallengeEntry(entryId: UUID, weekNumber: Int, year: Int, voterId: UUID) async throws {
        struct InsertVote: Codable {
            let entryId: UUID; let weekNumber: Int; let year: Int; let voterId: UUID
            enum CodingKeys: String, CodingKey {
                case entryId = "entry_id"; case weekNumber = "week_number"
                case year; case voterId = "voter_id"
            }
        }
        _ = try await sb.from("challenge_votes")
            .insert(InsertVote(entryId: entryId, weekNumber: weekNumber, year: year, voterId: voterId))
            .execute()
    }
}
