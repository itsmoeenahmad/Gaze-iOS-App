import SwiftUI

// MARK: - Outfit Gradient Card (fallback)

struct OutfitGradientCard: View {
    let gradientIndex: Int
    let cornerRadius: CGFloat

    var body: some View {
        LinearGradient(
            colors: GazeGradients.gradient(for: gradientIndex),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Outfit Card (shows real image > URL > gradient)

struct OutfitCard: View {
    let outfit: Outfit
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let local = MockDataService.shared.localImage(for: outfit.id) {
                // Locally uploaded photo (persisted across sessions)
                Image(uiImage: local)
                    .resizable()
                    .scaledToFill()
            } else if let urlStr = outfit.imageURL, let url = URL(string: urlStr) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.22))) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .transition(.opacity)
                    default:
                        OutfitGradientCard(gradientIndex: outfit.gradientIndex, cornerRadius: 0)
                    }
                }
            } else {
                OutfitGradientCard(gradientIndex: outfit.gradientIndex, cornerRadius: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - User Avatar

struct GazeAvatar: View {
    let user: GazeUser
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background always fills the circle so there's no empty space when image is fitted
            avatarFallback

            if let local = MockDataService.shared.localAvatarImage(for: user.id) {
                Image(uiImage: local)
                    .resizable()
                    .scaledToFit()
            } else if let urlStr = user.avatarURL, let url = URL(string: urlStr) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.18))) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                            .transition(.opacity)
                    default: EmptyView()
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.gazeBorder, lineWidth: 1))
    }

    private var avatarFallback: some View {
        ZStack {
            LinearGradient(
                colors: user.avatarColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(user.displayName.prefix(1)).uppercased())
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Score Badge

struct ScoreBadge: View {
    let score: Double
    let size: ScoreBadgeSize

    enum ScoreBadgeSize { case small, medium, large }

    private var fontSize: CGFloat {
        switch size { case .small: return 13; case .medium: return 16; case .large: return 22 }
    }
    private var padding: CGFloat {
        switch size { case .small: return 6; case .medium: return 8; case .large: return 12 }
    }

    var body: some View {
        Text(String(format: "%.1f", score))
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .foregroundStyle(score >= 7 ? .black : Color.gazeTextSecondary)
            .padding(.horizontal, padding)
            .padding(.vertical, padding * 0.6)
            .background(
                Capsule().fill(scoreColor)
            )
    }

    private var scoreColor: Color {
        switch score {
        case 9...:  return Color(hex: "#FFFFFF")
        case 8...:  return Color(hex: "#CCCCCC")
        case 7...:  return Color(hex: "#999999")
        default:    return Color(hex: "#555555")
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: StyleCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(category.rawValue)
                    .font(GazeType.labelMedium)
            }
            .foregroundStyle(isSelected ? .black : Color.gazeTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? category.accentColor : Color.gazeCard)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? category.accentColor : Color.gazeBorder,
                        lineWidth: 1
                    )
            )
            .contentShape(Capsule())
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(GazeAnimations.springSnappy, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shimmer

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gazeCard,
                        Color.gazeBorder,
                        Color.gazeCard,
                    ],
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint: .init(x: phase + 0.3, y: 0)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

// MARK: - Gaze Button

struct GazeButton: View {
    let label: String
    var icon: String? = nil
    var style: GazeButtonStyle = .primary
    let action: () -> Void

    enum GazeButtonStyle { case primary, secondary, ghost, destructive }

    var body: some View {
        Button(action: { GazeHaptics.medium(); action() }) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(label)
                    .font(GazeType.headlineSmall)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: style == .ghost ? 1 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch style {
        case .primary:     return .black
        case .secondary:   return Color.gazeTextPrimary
        case .ghost:       return Color.gazeTextPrimary
        case .destructive: return .white
        }
    }

    private var background: some View {
        Group {
            switch style {
            case .primary:
                LinearGradient(colors: [Color.gazeAccent, Color(hex: "#C8C8C8")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .secondary:
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.gazeCard)
            case .ghost:
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.clear)
            case .destructive:
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.gazeFire)
            }
        }
    }

    private var border: Color {
        switch style {
        case .ghost:   return Color.gazeBorder
        default:       return .clear
        }
    }
}

// MARK: - Follow Button

struct FollowButton: View {
    let isFollowing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isFollowing ? "Following" : "Follow")
                .font(GazeType.labelLarge)
                .foregroundStyle(isFollowing ? Color.gazeTextSecondary : .black)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isFollowing ? Color.gazeCard : Color.gazeAccent)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.gazeBorder, lineWidth: isFollowing ? 1 : 0)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(GazeAnimations.springSnappy, value: isFollowing)
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(GazeType.headlineMedium)
                .foregroundStyle(Color.gazeTextPrimary)
            Text(label)
                .font(GazeType.labelSmall)
                .foregroundStyle(Color.gazeTextSecondary)
                .tracking(0.5)
        }
    }
}

// MARK: - Heart Like Button (with sparkle burst)

struct HeartLikeButton: View {
    @Binding var isLiked: Bool
    let count: Int
    var size: CGFloat = 26
    var showCount: Bool = true
    let action: () -> Void

    @State private var bursting = false
    @State private var scale: CGFloat = 1.0

    private let heartColor = Color(hex: "#FF2D55")
    private let particles: [(angle: Double, symbol: String)] = [
        (0, "sparkle"), (45, "heart.fill"), (90, "sparkle"),
        (135, "heart.fill"), (180, "sparkle"), (225, "heart.fill"),
        (270, "sparkle"), (315, "heart.fill")
    ]

    var body: some View {
        Button {
            let wasLiked = isLiked
            GazeHaptics.fire()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                isLiked.toggle()
                scale = isLiked ? 1.3 : 0.85
            }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5).delay(0.1)) {
                scale = 1.0
            }
            if !wasLiked {
                bursting = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { bursting = false }
            }
            action()
        } label: {
            ZStack {
                // Burst particles
                if bursting {
                    ForEach(Array(particles.enumerated()), id: \.offset) { _, p in
                        SparkleParticle(angle: p.angle, symbol: p.symbol, color: heartColor)
                    }
                }
                VStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: size, weight: .medium))
                        .foregroundStyle(isLiked ? heartColor : Color.gazeTextSecondary)
                        .scaleEffect(scale)
                    if showCount {
                        Text("\(count.shortFormatted)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isLiked ? heartColor : Color.gazeTextSecondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SparkleParticle: View {
    let angle: Double
    let symbol: String
    let color: Color

    @State private var distance: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var particleScale: CGFloat = 0.5

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: symbol == "sparkle" ? 7 : 5, weight: .bold))
            .foregroundStyle(color)
            .scaleEffect(particleScale)
            .opacity(opacity)
            .offset(
                x: distance * CGFloat(cos(angle * .pi / 180)),
                y: distance * CGFloat(sin(angle * .pi / 180))
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) {
                    distance = 28
                    opacity = 0
                    particleScale = 1.2
                }
            }
    }
}

// MARK: - Number formatting

extension Int {
    var shortFormatted: String {
        switch self {
        case 1_000_000...: return String(format: "%.1fM", Double(self) / 1_000_000)
        case 1_000...:     return String(format: "%.1fK", Double(self) / 1_000)
        default:           return "\(self)"
        }
    }
}
