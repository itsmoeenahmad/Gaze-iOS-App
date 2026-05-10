import Foundation
import SwiftUI

// MARK: - Database row types (decoded from Supabase JSON)
// These exactly mirror the table columns, then get mapped to app types.

// MARK: - DBProfile

struct DBProfile: Codable, Hashable {
    let id: UUID
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
    let createdAt: Date
    let challengeWins: Int?

    enum CodingKeys: String, CodingKey {
        case id, username, bio, city
        case displayName    = "display_name"
        case avatarUrl      = "avatar_url"
        case styleCategory  = "style_category"
        case followerCount  = "follower_count"
        case followingCount = "following_count"
        case outfitCount    = "outfit_count"
        case isVerified     = "is_verified"
        case createdAt      = "created_at"
        case challengeWins  = "challenge_wins"
    }

    func toGazeUser(isFollowing: Bool = false) -> GazeUser {
        GazeUser(
            id: id,
            username: username,
            displayName: displayName.isEmpty ? username : displayName,
            avatarColorHex: avatarHex,
            city: city,
            bio: bio,
            styleScore: 0,
            styleCategory: StyleCategory(rawValue: styleCategory) ?? .minimalist,
            followerCount: followerCount,
            followingCount: followingCount,
            outfitCount: outfitCount,
            isVerified: isVerified,
            isFollowing: isFollowing,
            gradientIndex: abs(id.hashValue) % 20,
            avatarURL: avatarUrl,
            challengeWins: challengeWins ?? 0
        )
    }

    private var avatarHex: String {
        let palette = ["#2d1b69","#0a0a0a","#c94b4b","#b8860b","#5856D6",
                       "#8A8A8A","#FF9500","#636366","#6C6C70","#00C7BE"]
        return palette[abs(id.hashValue) % palette.count]
    }
}

// MARK: - DBOutfit

struct DBOutfit: Codable {
    let id: UUID
    let userId: UUID
    let imageUrl: String?
    let caption: String
    let brands: [String]
    let styleCategory: String
    let priceLevel: Int?
    let fireCount: Int
    let commentCount: Int
    let visibility: String
    let link: String?
    let createdAt: Date
    let deletedAt: Date?
    let profiles: DBProfile?        // joined via select("*, profiles(*)")

    enum CodingKeys: String, CodingKey {
        case id, caption, brands, visibility, link, profiles
        case userId        = "user_id"
        case imageUrl      = "image_url"
        case styleCategory = "style_category"
        case priceLevel    = "price_level"
        case fireCount     = "fire_count"
        case commentCount  = "comment_count"
        case createdAt     = "created_at"
        case deletedAt     = "deleted_at"
    }

    func toOutfit(firedByCurrentUser: Bool = false,
                  savedByCurrentUser: Bool = false) -> Outfit {
        Outfit(
            id: id,
            userId: userId,
            user: profiles?.toGazeUser(),
            gradientIndex: abs(id.hashValue) % 20,
            caption: caption,
            brands: brands,
            category: StyleCategory(rawValue: styleCategory) ?? .minimalist,
            priceLevel: PriceLevel(rawValue: priceLevel ?? 2) ?? .mid,
            city: profiles?.city ?? "",
            averageRating: 0,
            ratingCount: 0,
            fireCount: fireCount,
            commentCount: commentCount,
            timestamp: createdAt,
            isRatedByCurrentUser: firedByCurrentUser,
            isSaved: savedByCurrentUser,
            aspectRatio: 1.0,
            visibility: PostVisibility(rawValue: visibility) ?? .everyone,
            imageURL: imageUrl,
            linkURL: link
        )
    }
}

// MARK: - DBComment

struct DBComment: Codable {
    let id: UUID
    let outfitId: UUID
    let userId: UUID
    let text: String
    let createdAt: Date
    let likeCount: Int?
    let profiles: DBProfile?

    enum CodingKeys: String, CodingKey {
        case id, text, profiles
        case outfitId  = "outfit_id"
        case userId    = "user_id"
        case createdAt = "created_at"
        case likeCount = "like_count"
    }

    func toComment(isLiked: Bool = false) -> Comment {
        Comment(id: id, user: profiles?.toGazeUser(), text: text,
                timestamp: createdAt, isLiked: isLiked, likeCount: likeCount ?? 0)
    }
}

// MARK: - DBFriendRequest

struct DBFriendRequest: Codable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let status: String
    let createdAt: Date
    let fromProfile: DBProfile?

    enum CodingKeys: String, CodingKey {
        case id, status
        case fromUserId  = "from_user_id"
        case toUserId    = "to_user_id"
        case createdAt   = "created_at"
        case fromProfile = "from_profile"
    }

    func toFriendRequest() -> FriendRequest? {
        guard let profile = fromProfile else { return nil }
        return FriendRequest(
            id: id,
            fromUserId: fromUserId,
            toUserId: toUserId,
            fromUser: profile.toGazeUser(),
            timestamp: createdAt,
            status: FriendRequestStatus(rawValue: status) ?? .pending
        )
    }
}

// MARK: - DBFire

struct DBFire: Codable {
    let id: UUID
    let outfitId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case outfitId = "outfit_id"
        case userId   = "user_id"
    }
}

// MARK: - DBFollow

struct DBFollow: Codable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case followerId  = "follower_id"
        case followingId = "following_id"
    }
}

// MARK: - DBSaved

struct DBSaved: Codable {
    let id: UUID
    let userId: UUID
    let outfitId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case userId   = "user_id"
        case outfitId = "outfit_id"
    }
}

// MARK: - Saved outfit join (outfits with profiles via saved_outfits)

struct DBSavedJoin: Codable {
    let outfits: DBOutfit

    enum CodingKeys: String, CodingKey {
        case outfits
    }
}

// MARK: - DBNotification

struct DBNotification: Codable {
    let id: UUID
    let type: String
    let fromUserId: UUID
    let toUserId: UUID
    let outfitId: UUID?
    let message: String
    let createdAt: Date
    let isRead: Bool
    let fromProfile: DBProfile?

    enum CodingKeys: String, CodingKey {
        case id, message, type
        case fromUserId  = "from_user_id"
        case toUserId    = "user_id"
        case outfitId    = "post_id"
        case createdAt   = "created_at"
        case isRead      = "is_read"
        case fromProfile = "from_profile"
    }

    func toGazeNotification() -> GazeNotification? {
        guard let profile = fromProfile else { return nil }
        let notifType = NotificationType(rawValue: type) ?? .outfitRated
        return GazeNotification(
            id: id,
            type: notifType,
            fromUser: profile.toGazeUser(),
            outfit: nil,
            message: message,
            timestamp: createdAt,
            isRead: isRead
        )
    }
}

// MARK: - DBBlockedUser

struct DBBlockedUser: Codable {
    let id: UUID
    let blockerId: UUID
    let blockedId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case blockerId  = "blocker_id"
        case blockedId  = "blocked_id"
        case createdAt  = "created_at"
    }
}

// MARK: - DBChallengeEntry

struct DBChallengeEntry: Codable {
    let id: UUID
    let weekNumber: Int
    let year: Int
    let userId: UUID
    let outfitId: UUID
    let voteCount: Int
    let createdAt: Date
    let outfits: DBOutfit?

    enum CodingKeys: String, CodingKey {
        case id, outfits
        case weekNumber = "week_number"
        case year
        case userId     = "user_id"
        case outfitId   = "outfit_id"
        case voteCount  = "vote_count"
        case createdAt  = "created_at"
    }

    func toChallengeEntry(hasVoted: Bool = false) -> ChallengeEntry {
        ChallengeEntry(
            id: id,
            weekNumber: weekNumber,
            year: year,
            userId: userId,
            outfit: outfits?.toOutfit(),
            voteCount: voteCount,
            hasVoted: hasVoted,
            createdAt: createdAt
        )
    }
}
