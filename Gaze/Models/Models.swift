import Foundation
import SwiftUI

// MARK: - Style Category

enum StyleCategory: String, CaseIterable, Codable, Hashable {
    case streetwear  = "Streetwear"
    case quietLuxury = "Quiet Luxury"
    case monochrome  = "Monochrome"
    case summer      = "Summer"
    case minimalist  = "Minimalist"
    case vintage     = "Vintage"
    case athleisure  = "Athleisure"
    case formal      = "Formal"
    case techwear    = "Techwear"
    case grunge      = "Grunge"

    var icon: String {
        switch self {
        case .streetwear:  return "figure.walk"
        case .quietLuxury: return "sparkles"
        case .monochrome:  return "circle.lefthalf.filled"
        case .summer:      return "sun.max.fill"
        case .minimalist:  return "minus.circle"
        case .vintage:     return "clock.arrow.circlepath"
        case .athleisure:  return "bolt.fill"
        case .formal:      return "briefcase.fill"
        case .techwear:    return "cpu.fill"
        case .grunge:      return "flame.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .streetwear:  return Color(hex: "#FF4444")
        case .quietLuxury: return Color(hex: "#D4AF37")
        case .monochrome:  return Color(hex: "#FFFFFF")
        case .summer:      return Color(hex: "#FF9500")
        case .minimalist:  return Color(hex: "#8A8A8A")
        case .vintage:     return Color(hex: "#C9A96E")
        case .athleisure:  return Color(hex: "#00C7BE")
        case .formal:      return Color(hex: "#6C6C70")
        case .techwear:    return Color(hex: "#5856D6")
        case .grunge:      return Color(hex: "#636366")
        }
    }
}

// MARK: - Price Level

enum PriceLevel: Int, CaseIterable, Codable {
    case budget   = 1
    case mid      = 2
    case luxury   = 3
    case ultraLux = 4

    var label: String {
        switch self {
        case .budget:   return "Budget"
        case .mid:      return "Mid-Range"
        case .luxury:   return "Luxury"
        case .ultraLux: return "Ultra Lux"
        }
    }

    var symbol: String { String(repeating: "$", count: rawValue) }

    var color: Color {
        switch self {
        case .budget:   return Color.gazeTextSecondary
        case .mid:      return Color.gazeSuccess
        case .luxury:   return Color.gazeAccent
        case .ultraLux: return Color(hex: "#D4AF37")
        }
    }
}

// MARK: - Post Visibility

enum PostVisibility: String, Codable {
    case friends  = "friends"
    case everyone = "everyone"
}

// MARK: - User

struct GazeUser: Identifiable, Codable, Hashable {
    static func == (lhs: GazeUser, rhs: GazeUser) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    var username: String
    var displayName: String
    var avatarColorHex: String
    var city: String
    var university: String?
    var bio: String
    var styleScore: Double      // 0–10 average rating
    var styleCategory: StyleCategory
    var followerCount: Int
    var followingCount: Int
    var outfitCount: Int
    var isVerified: Bool
    var isFollowing: Bool
    var gradientIndex: Int      // for avatar gradient
    var avatarURL: String?      // remote or uploaded avatar photo URL
    var challengeWins: Int      // number of weekly challenge wins

    init(id: UUID, username: String, displayName: String, avatarColorHex: String,
         city: String, university: String? = nil, bio: String, styleScore: Double,
         styleCategory: StyleCategory, followerCount: Int, followingCount: Int,
         outfitCount: Int, isVerified: Bool, isFollowing: Bool, gradientIndex: Int,
         avatarURL: String? = nil, challengeWins: Int = 0) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarColorHex = avatarColorHex
        self.city = city
        self.university = university
        self.bio = bio
        self.styleScore = styleScore
        self.styleCategory = styleCategory
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.outfitCount = outfitCount
        self.isVerified = isVerified
        self.isFollowing = isFollowing
        self.gradientIndex = gradientIndex
        self.avatarURL = avatarURL
        self.challengeWins = challengeWins
    }

    var avatarColors: [Color] { GazeGradients.gradient(for: gradientIndex) }
    var scoreFormatted: String  { String(format: "%.1f", styleScore) }
    var rankBadge: String {
        switch styleScore {
        case 9...:  return "👑"
        case 8...:  return "🔥"
        case 7...:  return "⭐️"
        case 6...:  return "✨"
        default:    return ""
        }
    }
}

// MARK: - Friend Request

struct FriendRequest: Identifiable, Codable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    var fromUser: GazeUser?
    let timestamp: Date
    var status: FriendRequestStatus
}

enum FriendRequestStatus: String, Codable {
    case pending  = "pending"
    case accepted = "accepted"
    case declined = "declined"
}

// MARK: - Outfit

struct Outfit: Identifiable, Codable, Hashable {
    static func == (lhs: Outfit, rhs: Outfit) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    let userId: UUID
    var user: GazeUser?
    var gradientIndex: Int          // determines visual gradient
    var caption: String
    var brands: [String]
    var category: StyleCategory
    var priceLevel: PriceLevel
    var city: String
    var averageRating: Double       // 0–10
    var ratingCount: Int
    var fireCount: Int              // right-swipe count
    var commentCount: Int
    var timestamp: Date
    var isRatedByCurrentUser: Bool
    var isSaved: Bool
    var aspectRatio: Double         // card aspect, varies slightly
    var visibility: PostVisibility  // friends or everyone
    var imageURL: String?           // remote photo URL (nil = use gradient)
    /// Optional shop / product URL from `outfits.link`.
    var linkURL: String?

    init(id: UUID, userId: UUID, user: GazeUser? = nil, gradientIndex: Int,
         caption: String, brands: [String], category: StyleCategory,
         priceLevel: PriceLevel, city: String, averageRating: Double,
         ratingCount: Int, fireCount: Int, commentCount: Int, timestamp: Date,
         isRatedByCurrentUser: Bool, isSaved: Bool, aspectRatio: Double,
         visibility: PostVisibility = .everyone, imageURL: String? = nil,
         linkURL: String? = nil) {
        self.id = id
        self.userId = userId
        self.user = user
        self.gradientIndex = gradientIndex
        self.caption = caption
        self.brands = brands
        self.category = category
        self.priceLevel = priceLevel
        self.city = city
        self.averageRating = averageRating
        self.ratingCount = ratingCount
        self.fireCount = fireCount
        self.commentCount = commentCount
        self.timestamp = timestamp
        self.isRatedByCurrentUser = isRatedByCurrentUser
        self.isSaved = isSaved
        self.aspectRatio = aspectRatio
        self.visibility = visibility
        self.imageURL = imageURL
        self.linkURL = linkURL
    }

    /// Best-effort URL for opening the product link in Safari.
    var openableProductLinkURL: URL? {
        Self.normalizedLinkURL(linkURL)
    }

    static func normalizedLinkURL(_ raw: String?) -> URL? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        let withScheme: String
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            withScheme = trimmed
        } else {
            withScheme = "https://\(trimmed)"
        }
        return URL(string: withScheme)
    }

    var outfitColors: [Color] { GazeGradients.gradient(for: gradientIndex) }
    var ratingFormatted: String     { String(format: "%.1f", averageRating) }
    var timeAgoString: String {
        let diff = Date().timeIntervalSince(timestamp)
        switch diff {
        case ..<60:          return "just now"
        case ..<3600:        return "\(Int(diff/60))m"
        case ..<86400:       return "\(Int(diff/3600))h"
        default:             return "\(Int(diff/86400))d"
        }
    }
}

// MARK: - Rating

enum RatingValue: String, Codable {
    case fire = "fire"   // swipe right — strong positive
    case skip = "skip"   // swipe left  — pass
    case save = "save"   // bookmark

    var scoreContribution: Double {
        switch self {
        case .fire: return 8.5 + Double.random(in: 0...1.5)
        case .skip: return 4.0 + Double.random(in: 0...2.0)
        case .save: return 7.5 + Double.random(in: 0...1.5)
        }
    }
}

struct OutfitRating: Identifiable, Codable {
    let id: UUID
    let raterId: UUID
    let outfitId: UUID
    var value: RatingValue
    let timestamp: Date
}

// MARK: - Ranking Entry

struct RankingEntry: Identifiable {
    let id: UUID
    var user: GazeUser
    var rank: Int
    var score: Double
    var rankChange: Int         // +3 = moved up 3 spots, -1 = moved down 1
    var weeklyFires: Int
    var totalRatings: Int

    var rankChangeIcon: String {
        if rankChange > 0  { return "arrow.up" }
        if rankChange < 0  { return "arrow.down" }
        return "minus"
    }

    var rankChangeColor: Color {
        if rankChange > 0  { return Color.gazeSuccess }
        if rankChange < 0  { return Color.gazeFire }
        return Color.gazeTextMuted
    }
}

// MARK: - Notification

enum NotificationType: String, Codable {
    case newFollower, outfitRated, outfitFeatured, rankingUp, weeklyReport, newMatch
    case friendRequest = "friend_request"

    var icon: String {
        switch self {
        case .newFollower:    return "person.fill.badge.plus"
        case .outfitRated:   return "flame.fill"
        case .outfitFeatured: return "star.fill"
        case .rankingUp:     return "arrow.up.circle.fill"
        case .weeklyReport:  return "chart.bar.fill"
        case .newMatch:      return "heart.fill"
        case .friendRequest: return "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .newFollower:    return Color.gazeIce
        case .outfitRated:   return Color.gazeFire
        case .outfitFeatured: return Color.gazeAccent
        case .rankingUp:     return Color.gazeSuccess
        case .weeklyReport:  return Color(hex: "#5856D6")
        case .newMatch:      return Color(hex: "#FF2D55")
        case .friendRequest: return Color(hex: "#FF9500")
        }
    }
}

struct GazeNotification: Identifiable {
    let id: UUID
    let type: NotificationType
    let fromUser: GazeUser
    var outfit: Outfit?
    var message: String
    let timestamp: Date
    var isRead: Bool
}

// MARK: - Onboarding

struct StylePreferences {
    var selectedCategories: Set<StyleCategory> = []
    var priceRange: PriceLevel = .mid
    var city: String = ""
    var username: String = ""
    var displayName: String = ""
}

// MARK: - App State lives in AppViewModel as GazeAppState

enum GazeTab: Int, CaseIterable {
    case feed     = 0
    case explore  = 1
    case post     = 2
    case trending = 3
    case profile  = 4

    var icon: String {
        switch self {
        case .feed:     return "house.fill"
        case .explore:  return "safari.fill"
        case .post:     return "plus"
        case .trending: return "trophy.fill"
        case .profile:  return "person.fill"
        }
    }

    var unselectedIcon: String {
        switch self {
        case .feed:     return "house"
        case .explore:  return "safari"
        case .post:     return "plus"
        case .trending: return "trophy"
        case .profile:  return "person"
        }
    }

    var label: String {
        switch self {
        case .feed:     return "Friends"
        case .explore:  return "Explore"
        case .post:     return ""
        case .trending: return "Challenge"
        case .profile:  return "Profile"
        }
    }
}

// MARK: - Comment

struct Comment: Identifiable {
    let id: UUID
    var user: GazeUser?
    var text: String
    let timestamp: Date
    var isLiked: Bool
    var likeCount: Int
}

extension Notification.Name {
    static let gazeNewPost               = Notification.Name("gazeNewPost")
    static let gazeOutfitSaved           = Notification.Name("gazeOutfitSaved")
    static let gazeOutfitUnsaved         = Notification.Name("gazeOutfitUnsaved")
    static let gazeOutfitLiked           = Notification.Name("gazeOutfitLiked")
    static let gazeOutfitUnliked         = Notification.Name("gazeOutfitUnliked")
    static let gazeOutfitDeleted         = Notification.Name("gazeOutfitDeleted")
    static let gazeOutfitCommented       = Notification.Name("gazeOutfitCommented")
    static let gazeCommentDeleted        = Notification.Name("gazeCommentDeleted")
    static let gazeChallengeEntryDeleted = Notification.Name("gazeChallengeEntryDeleted")
    static let gazeChallengeEntryAdded   = Notification.Name("gazeChallengeEntryAdded")
    // object: Int (+1 follow, -1 unfollow) — keeps AppViewModel.currentUser.followingCount in sync
    static let gazeFollowingCountChanged = Notification.Name("gazeFollowingCountChanged")
    // posted after a follow/unfollow so HomeFeedViewModel refreshes both feeds
    static let gazeFollowStateChanged    = Notification.Name("gazeFollowStateChanged")
    // posted after blocking/unblocking a user — feeds and profile views should refresh
    static let gazeUserBlocked           = Notification.Name("gazeUserBlocked")
}

// MARK: - Challenge Entry

struct ChallengeEntry: Identifiable {
    let id: UUID
    let weekNumber: Int
    let year: Int
    let userId: UUID
    var outfit: Outfit?
    var voteCount: Int
    var hasVoted: Bool
    let createdAt: Date
}

enum RankingScope: String, CaseIterable {
    case city   = "City"
    case global = "Global"
}

// MARK: - Challenge System (new production tables)

enum ChallengeStatus: String, Codable {
    case collecting, voting, finals, closed, archived
}

enum SubmissionStatus: String, Codable {
    case pending, confirmed, disqualified
}

struct ChallengeWeek: Identifiable, Codable {
    let id: UUID
    let isoWeek: Int
    let isoYear: Int
    let themeName: String
    let themeEmoji: String
    let themeDescription: String
    let themeGradientStart: String
    let themeGradientEnd: String
    let status: ChallengeStatus
    let startsAt: Date
    let collectingEndsAt: Date
    let finalsEndsAt: Date
    let createdAt: Date
    var mySubmission: MySubmission?
    var myFinalsVoteId: UUID?

    struct MySubmission: Codable {
        let id: UUID
        var status: SubmissionStatus
        var imageUrl: String
        var caption: String?
        var voteCount: Int
        var likeCount: Int
        var commentCount: Int
        var votingWindowStart: Date?
        var votingWindowEnd: Date?
        var confirmedAt: Date?

        var isVotingWindowOpen: Bool {
            guard let start = votingWindowStart, let end = votingWindowEnd else { return false }
            return Date() >= start && Date() <= end
        }

        enum CodingKeys: String, CodingKey {
            case id, status, caption
            case imageUrl           = "image_url"
            case voteCount          = "vote_count"
            case likeCount          = "like_count"
            case commentCount       = "comment_count"
            case votingWindowStart  = "voting_window_start"
            case votingWindowEnd    = "voting_window_end"
            case confirmedAt        = "confirmed_at"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, status
        case isoWeek            = "iso_week"
        case isoYear            = "iso_year"
        case themeName          = "theme_name"
        case themeEmoji         = "theme_emoji"
        case themeDescription   = "theme_description"
        case themeGradientStart = "theme_gradient_start"
        case themeGradientEnd   = "theme_gradient_end"
        case startsAt           = "starts_at"
        case collectingEndsAt   = "collecting_ends_at"
        case finalsEndsAt       = "finals_ends_at"
        case createdAt          = "created_at"
        case mySubmission       = "my_submission"
        case myFinalsVoteId     = "my_finals_vote_id"
    }
}

struct ChallengeSubmission: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let imageUrl: String
    var caption: String?
    var status: SubmissionStatus
    var voteCount: Int
    var likeCount: Int
    var commentCount: Int
    var votingWindowStart: Date?
    var votingWindowEnd: Date?
    var confirmedAt: Date?
    var submissionDay: String?
    var hasVoted: Bool
    var hasLiked: Bool
    var isVotingWindowOpen: Bool
    var username: String?
    var displayName: String?
    var avatarUrl: String?
    // finals only
    var finalsVoteCount: Int?
    var userHasVotedFinals: Bool?

    enum CodingKeys: String, CodingKey {
        case id, caption, status, username
        case userId             = "user_id"
        case imageUrl           = "image_url"
        case voteCount          = "vote_count"
        case likeCount          = "like_count"
        case commentCount       = "comment_count"
        case votingWindowStart  = "voting_window_start"
        case votingWindowEnd    = "voting_window_end"
        case confirmedAt        = "confirmed_at"
        case submissionDay      = "submission_day"
        case hasVoted           = "has_voted"
        case hasLiked           = "has_liked"
        case isVotingWindowOpen = "is_voting_window_open"
        case displayName        = "display_name"
        case avatarUrl          = "avatar_url"
        case finalsVoteCount    = "finals_vote_count"
        case userHasVotedFinals = "user_has_voted_finals"
    }
}

struct ChallengeComment: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let body: String
    let createdAt: Date
    var username: String?
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, body, username
        case userId    = "user_id"
        case createdAt = "created_at"
        case avatarUrl = "avatar_url"
    }
}

struct ChallengeWinner: Identifiable, Codable {
    let id: UUID
    let challengeId: UUID
    let submissionId: UUID
    let winnerUserId: UUID
    let winnerVoteCount: Int
    let createdAt: Date
    var winnerUsername: String?
    var winnerAvatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case challengeId      = "challenge_id"
        case submissionId     = "submission_id"
        case winnerUserId     = "winner_user_id"
        case winnerVoteCount  = "winner_vote_count"
        case createdAt        = "created_at"
        case winnerUsername   = "winner_username"
        case winnerAvatarUrl  = "winner_avatar_url"
    }
}
