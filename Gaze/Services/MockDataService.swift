import Foundation
import SwiftUI

// MARK: - Mock Data Service
// Simulates a real backend — replace with actual API calls in production

final class MockDataService {

    static let shared = MockDataService()
    private init() {}

    // MARK: - Users

    let mockUsers: [GazeUser] = [
        GazeUser(id: UUID(), username: "zara.fits", displayName: "Zara Müller", avatarColorHex: "#2d1b69",
                 city: "Berlin", university: "HU Berlin", bio: "quiet luxury only 🤍", styleScore: 9.2,
                 styleCategory: .quietLuxury, followerCount: 12400, followingCount: 380, outfitCount: 94,
                 isVerified: true, isFollowing: false, gradientIndex: 1),

        GazeUser(id: UUID(), username: "noir.leo", displayName: "Leo Noir", avatarColorHex: "#0a0a0a",
                 city: "Paris", university: nil, bio: "all black everything", styleScore: 8.7,
                 styleCategory: .monochrome, followerCount: 8900, followingCount: 210, outfitCount: 67,
                 isVerified: true, isFollowing: true, gradientIndex: 2),

        GazeUser(id: UUID(), username: "street.kai", displayName: "Kai Park", avatarColorHex: "#c94b4b",
                 city: "Seoul", university: "Yonsei", bio: "streetwear is culture 🔥", styleScore: 8.4,
                 styleCategory: .streetwear, followerCount: 34200, followingCount: 890, outfitCount: 203,
                 isVerified: true, isFollowing: false, gradientIndex: 4),

        GazeUser(id: UUID(), username: "mila.vintage", displayName: "Mila Costa", avatarColorHex: "#b8860b",
                 city: "Milan", university: "Politecnico", bio: "thrifted & thriving 🌿", styleScore: 7.9,
                 styleCategory: .vintage, followerCount: 5600, followingCount: 1200, outfitCount: 41,
                 isVerified: false, isFollowing: true, gradientIndex: 16),

        GazeUser(id: UUID(), username: "techxjun", displayName: "Jun Nakamura", avatarColorHex: "#5856D6",
                 city: "Tokyo", university: "Waseda", bio: "gorpcore / techwear", styleScore: 8.1,
                 styleCategory: .techwear, followerCount: 18700, followingCount: 430, outfitCount: 128,
                 isVerified: true, isFollowing: false, gradientIndex: 10),

        GazeUser(id: UUID(), username: "lena.minimal", displayName: "Lena Weber", avatarColorHex: "#8A8A8A",
                 city: "Zurich", university: "ETH Zürich", bio: "less is more ✦", styleScore: 8.8,
                 styleCategory: .minimalist, followerCount: 9100, followingCount: 156, outfitCount: 55,
                 isVerified: false, isFollowing: false, gradientIndex: 7),

        GazeUser(id: UUID(), username: "amara.sun", displayName: "Amara Diallo", avatarColorHex: "#FF9500",
                 city: "London", university: "UCL", bio: "summer never ends 🌞", styleScore: 7.6,
                 styleCategory: .summer, followerCount: 4200, followingCount: 670, outfitCount: 33,
                 isVerified: false, isFollowing: true, gradientIndex: 19),

        GazeUser(id: UUID(), username: "max.grunge", displayName: "Max Brenner", avatarColorHex: "#636366",
                 city: "New York", university: "NYU", bio: "distressed & obsessed", styleScore: 7.3,
                 styleCategory: .grunge, followerCount: 3800, followingCount: 940, outfitCount: 29,
                 isVerified: false, isFollowing: false, gradientIndex: 14),

        GazeUser(id: UUID(), username: "sofia.formal", displayName: "Sofia Reyes", avatarColorHex: "#6C6C70",
                 city: "Madrid", university: "IE University", bio: "boardroom to bar 🥂", styleScore: 8.3,
                 styleCategory: .formal, followerCount: 7200, followingCount: 290, outfitCount: 76,
                 isVerified: true, isFollowing: false, gradientIndex: 8),

        GazeUser(id: UUID(), username: "rio.athleisure", displayName: "Rio Santos", avatarColorHex: "#00C7BE",
                 city: "São Paulo", university: nil, bio: "gym to street 💪", styleScore: 7.8,
                 styleCategory: .athleisure, followerCount: 6400, followingCount: 512, outfitCount: 88,
                 isVerified: false, isFollowing: true, gradientIndex: 15),
    ]

    // MARK: - Current User (logged in)
    var currentUser = GazeUser(
        id: UUID(),
        username: "you",
        displayName: "Your Name",
        avatarColorHex: "#F5C518",
        city: "Berlin",
        university: "HU Berlin",
        bio: "style is communication 🎯",
        styleScore: 7.4,
        styleCategory: .minimalist,
        followerCount: 847,
        followingCount: 312,
        outfitCount: 12,
        isVerified: false,
        isFollowing: false,
        gradientIndex: 6
    )

    // Track daily post count for the current session
    var dailyPostCount: Int = 0

    // In-memory cache for uploaded UIImages (keyed by outfit UUID)
    var imageCache: [UUID: UIImage] = [:]
    var avatarCache: [UUID: UIImage] = [:]

    // MARK: - Local disk persistence for uploaded photos

    private func localImageURL(for id: UUID) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(id.uuidString).jpg")
    }

    private func localAvatarURL(for userId: UUID) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatar_\(userId.uuidString).jpg")
    }

    func saveAvatarLocally(_ image: UIImage, userId: UUID) {
        avatarCache[userId] = image
        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: localAvatarURL(for: userId))
        }
    }

    func clearAvatarLocally(userId: UUID) {
        avatarCache.removeValue(forKey: userId)
        try? FileManager.default.removeItem(at: localAvatarURL(for: userId))
    }

    func localAvatarImage(for userId: UUID) -> UIImage? {
        if let cached = avatarCache[userId] { return cached }
        let url = localAvatarURL(for: userId)
        guard FileManager.default.fileExists(atPath: url.path),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        avatarCache[userId] = img
        return img
    }

    func saveImageLocally(_ image: UIImage, outfitId: UUID) {
        imageCache[outfitId] = image
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: localImageURL(for: outfitId))
        }
    }

    func localImage(for id: UUID) -> UIImage? {
        if let cached = imageCache[id] { return cached }
        let url = localImageURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache[id] = img   // warm the memory cache
        return img
    }

    // MARK: - Demo Users (match the Pinterest screenshots)

    let demoUsers: [GazeUser] = [
        GazeUser(id: UUID(uuidString: "A1000001-0000-0000-0000-000000000001")!, username: "rhys.larsen", displayName: "Rhys Larsen", avatarColorHex: "#1c1c1e",
                 city: "Copenhagen", bio: "clean fits only", styleScore: 9.4,
                 styleCategory: .quietLuxury, followerCount: 41200, followingCount: 312, outfitCount: 88,
                 isVerified: true, isFollowing: false, gradientIndex: 2),
        GazeUser(id: UUID(uuidString: "A1000002-0000-0000-0000-000000000002")!, username: "joe.bennett", displayName: "Joe Bennett", avatarColorHex: "#8B6914",
                 city: "London", bio: "elevated basics", styleScore: 9.1,
                 styleCategory: .quietLuxury, followerCount: 28700, followingCount: 198, outfitCount: 64,
                 isVerified: true, isFollowing: false, gradientIndex: 16),
        GazeUser(id: UUID(uuidString: "A1000003-0000-0000-0000-000000000003")!, username: "vainclub", displayName: "Vainclub", avatarColorHex: "#1c3557",
                 city: "Stockholm", bio: "men's minimalism", styleScore: 9.0,
                 styleCategory: .minimalist, followerCount: 67400, followingCount: 89, outfitCount: 203,
                 isVerified: true, isFollowing: false, gradientIndex: 10),
        GazeUser(id: UUID(uuidString: "A1000004-0000-0000-0000-000000000004")!, username: "antonela.finds", displayName: "Antonela", avatarColorHex: "#7B2D42",
                 city: "Milan", bio: "vintage collector 🍂", styleScore: 8.9,
                 styleCategory: .vintage, followerCount: 19300, followingCount: 445, outfitCount: 112,
                 isVerified: false, isFollowing: false, gradientIndex: 17),
        GazeUser(id: UUID(uuidString: "A1000005-0000-0000-0000-000000000005")!, username: "sara.studio", displayName: "Sara", avatarColorHex: "#0a0a0a",
                 city: "Paris", bio: "all black, always", styleScore: 9.3,
                 styleCategory: .minimalist, followerCount: 54100, followingCount: 167, outfitCount: 97,
                 isVerified: true, isFollowing: false, gradientIndex: 2),
        GazeUser(id: UUID(uuidString: "A1000006-0000-0000-0000-000000000006")!, username: "karina.carreon", displayName: "Karina Carreón", avatarColorHex: "#1a1a2e",
                 city: "Mexico City", bio: "YSL & vibes 🖤", styleScore: 9.2,
                 styleCategory: .streetwear, followerCount: 38900, followingCount: 521, outfitCount: 155,
                 isVerified: true, isFollowing: false, gradientIndex: 4),
        GazeUser(id: UUID(uuidString: "A1000007-0000-0000-0000-000000000007")!, username: "hairstyles.daily", displayName: "Hairstyles", avatarColorHex: "#2c2c2e",
                 city: "NYC", bio: "denim head to toe", styleScore: 8.7,
                 styleCategory: .streetwear, followerCount: 23600, followingCount: 712, outfitCount: 89,
                 isVerified: false, isFollowing: false, gradientIndex: 14),
        GazeUser(id: UUID(uuidString: "A1000008-0000-0000-0000-000000000008")!, username: "sandra.ql", displayName: "Sandra", avatarColorHex: "#6B4C2A",
                 city: "Zurich", bio: "Chanel & cobblestones ✨", styleScore: 9.5,
                 styleCategory: .quietLuxury, followerCount: 72000, followingCount: 204, outfitCount: 134,
                 isVerified: true, isFollowing: false, gradientIndex: 16),
    ]

    // MARK: - Demo Outfits (Pinterest-style, always pinned at top of Explore)

    var demoOutfits: [Outfit] {
        let u = demoUsers
        let base = Date().addingTimeInterval(-3600)
        return [
            Outfit(id: UUID(uuidString: "B1000001-0000-0000-0000-000000000001")!,
                   userId: u[0].id, user: u[0], gradientIndex: 2,
                   caption: "black polo + light wash — the only combo you need",
                   brands: ["Lulu Lemon", "Cos"], category: .quietLuxury, priceLevel: .mid,
                   city: "Copenhagen", averageRating: 9.4, ratingCount: 2140,
                   fireCount: 1840, commentCount: 312, timestamp: base,
                   isRatedByCurrentUser: false, isSaved: false, aspectRatio: 0.8,
                   imageURL: "https://images.unsplash.com/photo-1617196034183-421b4040ed20?w=600&h=900&fit=crop&crop=top&auto=format",
                   linkURL: "https://www.uniqlo.com"),

            Outfit(id: UUID(uuidString: "B1000002-0000-0000-0000-000000000002")!,
                   userId: u[1].id, user: u[1], gradientIndex: 16,
                   caption: "camel bomber, black everything else. old money energy",
                   brands: ["COS", "Zara", "Common Projects"], category: .quietLuxury, priceLevel: .luxury,
                   city: "London", averageRating: 9.1, ratingCount: 1870,
                   fireCount: 1620, commentCount: 287, timestamp: base.addingTimeInterval(-1800),
                   isRatedByCurrentUser: false, isSaved: false, aspectRatio: 1.0,
                   imageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&h=900&fit=crop&crop=top&auto=format"),

            Outfit(id: UUID(uuidString: "B1000003-0000-0000-0000-000000000003")!,
                   userId: u[2].id, user: u[2], gradientIndex: 10,
                   caption: "men's navy look — minimalist uniform done right",
                   brands: ["Uniqlo", "Arket", "Veja"], category: .minimalist, priceLevel: .mid,
                   city: "Stockholm", averageRating: 9.0, ratingCount: 3210,
                   fireCount: 2890, commentCount: 541, timestamp: base.addingTimeInterval(-3600),
                   isRatedByCurrentUser: false, isSaved: false, aspectRatio: 0.8,
                   imageURL: "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=600&h=900&fit=crop&crop=top&auto=format"),

            Outfit(id: UUID(uuidString: "B1000004-0000-0000-0000-000000000004")!,
                   userId: u[3].id, user: u[3], gradientIndex: 17,
                   caption: "burgundy cardigan season has officially started 🍂",
                   brands: ["Vintage", "Mango", "& Other Stories"], category: .vintage, priceLevel: .budget,
                   city: "Milan", averageRating: 8.9, ratingCount: 1450,
                   fireCount: 1340, commentCount: 198, timestamp: base.addingTimeInterval(-5400),
                   isRatedByCurrentUser: false, isSaved: false, aspectRatio: 1.0,
                   imageURL: "https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=600&h=900&fit=crop&crop=top&auto=format"),

            Outfit(id: UUID(uuidString: "B1000005-0000-0000-0000-000000000005")!,
                   userId: u[4].id, user: u[4], gradientIndex: 2,
                   caption: "mirror check before I go 🖤",
                   brands: ["Zara", "The Row"], category: .minimalist, priceLevel: .mid,
                   city: "Paris", averageRating: 9.3, ratingCount: 2680,
                   fireCount: 2450, commentCount: 419, timestamp: base.addingTimeInterval(-7200),
                   isRatedByCurrentUser: false, isSaved: false, aspectRatio: 0.8,
                   imageURL: "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&h=900&fit=crop&crop=top&auto=format"),

            Outfit(id: UUID(uuidString: "B1000006-0000-0000-0000-000000000006")!,
                   userId: u[5].id, user: u[5], gradientIndex: 4,
                   caption: "crop + wide-leg + YSL bag. the formula.",
                   brands: ["YSL", "Zara", "Levi's"], category: .streetwear, priceLevel: .luxury,
                   city: "Mexico City", averageRating: 9.2, ratingCount: 3100,
                   fireCount: 2760, commentCount: 503, timestamp: base.addingTimeInterval(-9000),
                   isRatedByCurrentUser: false, isSaved: false, aspectRatio: 1.0,
                   imageURL: "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=600&h=900&fit=crop&crop=top&auto=format"),

            Outfit(id: UUID(uuidString: "B1000007-0000-0000-0000-000000000007")!,
                   userId: u[6].id, user: u[6], gradientIndex: 14,
                   caption: "dark denim double — effortless or what",
                   brands: ["Levi's", "Carhartt", "Dr. Martens"], category: .streetwear, priceLevel: .mid,
                   city: "NYC", averageRating: 8.7, ratingCount: 1920,
                   fireCount: 1710, commentCount: 267, timestamp: base.addingTimeInterval(-10800),
                   isRatedByCurrentUser: false, isSaved: false, aspectRatio: 0.8,
                   imageURL: "https://images.unsplash.com/photo-1539109136881-3be02a4a1855?w=600&h=900&fit=crop&crop=top&auto=format"),

            Outfit(id: UUID(uuidString: "B1000008-0000-0000-0000-000000000008")!,
                   userId: u[7].id, user: u[7], gradientIndex: 16,
                   caption: "brown coat + Chanel. crouching by a door. iconic.",
                   brands: ["Chanel", "Totême", "Loro Piana"], category: .quietLuxury, priceLevel: .ultraLux,
                   city: "Zurich", averageRating: 9.5, ratingCount: 4200,
                   fireCount: 3890, commentCount: 712, timestamp: base.addingTimeInterval(-12600),
                   isRatedByCurrentUser: false, isSaved: false, aspectRatio: 1.0,
                   imageURL: "https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=600&h=900&fit=crop&crop=top&auto=format"),
        ]
    }

    // MARK: - Photo URLs (Unsplash — curated outfit & street-style photos)

    private let photoURLs = [
        // Street style — women
        "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1483985988355-763728e1935b?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1487222444282-c7898cc46c1d?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1517841905240-47296d8a8cec?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1524504388593-2a2a3c2f67e0?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1539109136881-3be02a4a1855?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1548142813-c348350df52b?w=600&h=900&fit=crop&crop=top&auto=format",
        // Streetwear / urban
        "https://images.unsplash.com/photo-1496440001469-9bfedce1bd9b?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1521572163361-9516796d57b9?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1566206091558-7f218b696731?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1576566588028-4147f3842f27?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1581044777550-4cfa60707c03?w=600&h=900&fit=crop&crop=top&auto=format",
        // Minimal / quiet luxury
        "https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1484328152053-eda39c7b5c0e?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1472289065668-ce650ac443d2?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1544441893-675973e31985?w=600&h=900&fit=crop&crop=top&auto=format",
        // Editorial / fashion forward
        "https://images.unsplash.com/photo-1506543730435-e2212279f8d8?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1485968579580-b6d095142e6e?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1520975916090-c04e5a3f4b7c?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1594938298603-c8148c4b4f62?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1618354691373-d851c5c3a990?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1612731959659-c21440c1cfdd?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1622519407650-3df9883f76a5?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1536243298747-ea8874136d64?w=600&h=900&fit=crop&crop=top&auto=format",
        "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=600&h=900&fit=crop&crop=top&auto=format",
    ]

    func photoURL(for index: Int) -> String {
        photoURLs[index % photoURLs.count]
    }

    // MARK: - Outfits

    func generateOutfits(count: Int = 30, includeDemos: Bool = false) -> [Outfit] {
        if includeDemos { return demoOutfits + generateOutfits(count: count) }

        let captions = [
            "Berlin winter uniform 🖤",
            "Monochrome Monday 🤍",
            "Seoul street energy 🔥",
            "Quiet luxury Sunday",
            "Thrift flip of the week",
            "All Rick Owens, no excuses",
            "Gorpcore is not a vibe, it's a lifestyle",
            "This fit has 3 layers of meaning",
            "Vintage Levi's & a black turtleneck. done.",
            "Airport fit. no excuses.",
            "Pre-spring in Tokyo 🌸",
            "London grey skies call for this",
            "Margiela tabis finally broke in",
            "Zara can actually deliver sometimes",
            "Uniform dressing, day 47",
            "Summer in Milan 🇮🇹",
            "Acne Studios just dropped, I caught it",
            "This is how you wear trousers",
            "Athleisure done right 💫",
            "Boardroom ready 🥂",
            "NYC energy is different",
            "Seoul → Tokyo pipeline fit",
            "Concept: invisible luxury",
            "Thrift store architecture",
            "The fit that started the follow train",
        ]

        let brandSets: [[String]] = [
            ["Rick Owens", "Dr. Martens"],
            ["Acne Studios", "A.P.C."],
            ["Carhartt", "Nike", "New Balance"],
            ["Zara", "COS", "Mango"],
            ["Maison Margiela", "Helmut Lang"],
            ["Uniqlo", "Muji", "Arket"],
            ["Stone Island", "Nike ACG"],
            ["Comme des Garçons", "Yohji Yamamoto"],
            ["Stüssy", "Supreme", "Carhartt"],
            ["Theory", "Totême", "The Row"],
            ["Salomon", "Arc'teryx", "Patagonia"],
            ["Vintage Levi's", "Vintage Carhartt"],
            ["Loewe", "Bottega Veneta"],
            ["Fear of God Essentials", "Jordan Brand"],
            ["Dior Men", "Loro Piana"],
        ]

        let cities = ["Berlin", "Paris", "Seoul", "Tokyo", "Milan", "London", "NYC", "Zurich", "Madrid", "São Paulo"]

        return (0..<count).map { i in
            let user = mockUsers[i % mockUsers.count]
            let hoursAgo = Double(Int.random(in: 0...72))
            return Outfit(
                id: UUID(),
                userId: user.id,
                user: user,
                gradientIndex: i % GazeGradients.outfitPalettes.count,
                caption: captions[i % captions.count],
                brands: Array(brandSets[i % brandSets.count].prefix(Int.random(in: 1...3))),
                category: StyleCategory.allCases[i % StyleCategory.allCases.count],
                priceLevel: PriceLevel(rawValue: (i % 4) + 1) ?? .mid,
                city: cities[i % cities.count],
                averageRating: Double.random(in: 6.0...9.8),
                ratingCount: Int.random(in: 12...1240),
                fireCount: Int.random(in: 8...890),
                commentCount: Int.random(in: 2...156),
                timestamp: Date().addingTimeInterval(-hoursAgo * 3600),
                isRatedByCurrentUser: false,
                isSaved: false,
                aspectRatio: [1.0, 1.0, 0.8, 1.25][i % 4],
                visibility: i % 3 == 0 ? .friends : .everyone,
                imageURL: photoURL(for: i)
            )
        }
    }

    func generateUsers(count: Int) -> [GazeUser] {
        Array(mockUsers.prefix(count))
    }

    // MARK: - Rankings

    func generateRankings(scope: RankingScope) -> [RankingEntry] {
        let users: [GazeUser]
        switch scope {
        case .city:   users = Array(mockUsers.prefix(8))
        case .global: users = mockUsers
        }

        return users.enumerated().map { index, user in
            RankingEntry(
                id: user.id,
                user: user,
                rank: index + 1,
                score: user.styleScore,
                rankChange: [-3, -2, -1, 0, 0, 1, 1, 2, 3, 4][index % 10],
                weeklyFires: Int.random(in: 200...2400),
                totalRatings: Int.random(in: 400...5000)
            )
        }
    }

    // MARK: - Notifications

    func generateNotifications() -> [GazeNotification] {
        let types: [NotificationType] = [.outfitRated, .newFollower, .outfitFeatured, .rankingUp, .outfitRated, .newFollower, .weeklyReport, .outfitRated]
        let messages = [
            "rated your latest outfit 🔥",
            "started following you",
            "Your fit is trending in Berlin",
            "You moved up 3 spots in the city ranking!",
            "gave your outfit a fire rating",
            "just followed you",
            "This week: 847 fires, top 12% globally",
            "thinks your fit is iconic",
        ]

        let outfits = generateOutfits(count: 4)

        return (0..<8).map { i in
            GazeNotification(
                id: UUID(),
                type: types[i],
                fromUser: mockUsers[i % mockUsers.count],
                outfit: i % 2 == 0 ? outfits[i % outfits.count] : nil,
                message: messages[i],
                timestamp: Date().addingTimeInterval(-Double(i * i * 900)),
                isRead: i > 2
            )
        }
    }

    // MARK: - Explore Feed

    func generateExploreFeed() -> [StyleCategory: [Outfit]] {
        var result: [StyleCategory: [Outfit]] = [:]
        let all = generateOutfits(count: 50)
        for category in StyleCategory.allCases {
            result[category] = all.filter { $0.category == category } + all.prefix(3)
        }
        return result
    }
}
