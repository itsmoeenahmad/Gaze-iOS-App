import SwiftUI
import UIKit

// MARK: - Outfit Detail View

struct OutfitDetailView: View {

    let outfit: Outfit
    @Environment(\.dismiss) private var dismiss
    @State private var isSaved: Bool
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var commentCount: Int
    @State private var isFollowingUser: Bool
    @State private var appeared = false
    @State private var showShareSheet = false
    @State private var showUserProfile = false
    @State private var showComments = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteFailedAlert = false
    @State private var deleteFailedMessage = ""
    @State private var showBlockConfirm = false

    private var isOwnPost: Bool {
        outfit.userId == SupabaseManager.shared.currentUserId
    }

    init(outfit: Outfit) {
        self.outfit = outfit
        _isSaved = State(initialValue: outfit.isSaved)
        _isLiked = State(initialValue: outfit.isRatedByCurrentUser)
        _likeCount = State(initialValue: outfit.fireCount)
        _commentCount = State(initialValue: outfit.commentCount)
        _isFollowingUser = State(initialValue: outfit.user?.isFollowing ?? false)
    }

    var body: some View {
        ZStack {
            Color.gazeBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Full-bleed outfit image
                        GeometryReader { geo in
                            let imgHeight = geo.size.width * 1.25
                            ZStack(alignment: .bottomLeading) {
                                OutfitCard(outfit: outfit, cornerRadius: 0)
                                    .frame(width: geo.size.width, height: imgHeight)
                                    .clipped()

                                // Gradient overlay
                                LinearGradient(
                                    colors: [.clear, .clear, Color.black.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(width: geo.size.width, height: imgHeight)

                            }
                        }
                        .aspectRatio(4/5, contentMode: .fit)
                        // Info section
                        VStack(alignment: .leading, spacing: 20) {
                            // User row
                            if let user = outfit.user {
                                HStack(spacing: 12) {
                                    Button { showUserProfile = true } label: {
                                        GazeAvatar(user: user, size: 48)
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(user.displayName)
                                                .font(GazeType.headlineMedium)
                                                .foregroundStyle(Color.gazeTextPrimary)
                                            if user.isVerified {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.gazeAccent)
                                            }
                                        }
                                        HStack(spacing: 8) {
                                            Text("@\(user.username)")
                                            Text("·")
                                            Text(outfit.city)
                                            Text("·")
                                            Text(outfit.timeAgoString)
                                        }
                                        .font(GazeType.labelSmall)
                                        .foregroundStyle(Color.gazeTextSecondary)
                                    }

                                    Spacer()

                                    if !isOwnPost {
                                        FollowButton(isFollowing: isFollowingUser) {
                                            toggleFollow(user: user)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            }

                            // Caption
                            Text(outfit.caption)
                                .font(GazeType.bodyLarge)
                                .foregroundStyle(Color.gazeTextPrimary)
                                .lineSpacing(3)
                                .padding(.horizontal, 20)

                            if let productURL = outfit.openableProductLinkURL {
                                Link(destination: productURL) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "link.circle.fill")
                                            .font(.system(size: 18))
                                        Text("Open product link")
                                            .font(GazeType.bodyMedium)
                                        Spacer(minLength: 0)
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.gazeTextMuted)
                                    }
                                    .foregroundStyle(Color.gazeAccent)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gazeCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.gazeBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 20)
                            }

                            // Brands
                            VStack(alignment: .leading, spacing: 8) {
                                Text("BRANDS")
                                    .font(GazeType.labelSmall)
                                    .foregroundStyle(Color.gazeTextMuted)
                                    .tracking(1.5)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(outfit.brands, id: \.self) { brand in
                                            Text(brand)
                                                .font(GazeType.labelLarge)
                                                .foregroundStyle(Color.gazeTextPrimary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(Color.gazeCard)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                                .strokeBorder(Color.gazeBorder, lineWidth: 1)
                                                        )
                                                )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            // Interactive action row
                            HStack(spacing: 24) {
                                // Like / Heart
                                HeartLikeButton(isLiked: $isLiked, count: likeCount) {
                                    // isLiked is already toggled by HeartLikeButton before this closure runs
                                    let nowLiked = isLiked
                                    likeCount += nowLiked ? 1 : -1
                                    NotificationCenter.default.post(
                                        name: nowLiked ? .gazeOutfitLiked : .gazeOutfitUnliked,
                                        object: outfit.id)
                                    if let userId = SupabaseManager.shared.currentUserId {
                                        Task {
                                            do {
                                                if nowLiked { try await SupabaseService.shared.addFire(outfitId: outfit.id, userId: userId) }
                                                else        { try await SupabaseService.shared.removeFire(outfitId: outfit.id, userId: userId) }
                                            } catch {
                                                // Rollback
                                                withAnimation(GazeAnimations.springBouncy) {
                                                    isLiked = !nowLiked
                                                    likeCount += nowLiked ? -1 : 1
                                                }
                                                NotificationCenter.default.post(
                                                    name: nowLiked ? .gazeOutfitUnliked : .gazeOutfitLiked,
                                                    object: outfit.id)
                                            }
                                        }
                                    }
                                }

                                // Comments
                                Button { showComments = true } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "bubble.left")
                                            .font(.system(size: 26, weight: .regular))
                                            .foregroundStyle(Color.gazeTextSecondary)
                                        Text("\(commentCount)")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.gazeTextSecondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                // Save
                                Button {
                                    GazeHaptics.light()
                                    let wasSaved = isSaved
                                    withAnimation(GazeAnimations.springBouncy) { isSaved.toggle() }
                                    if let userId = SupabaseManager.shared.currentUserId {
                                        Task {
                                            do {
                                                if wasSaved {
                                                    try await SupabaseService.shared.unsaveOutfit(outfitId: outfit.id, userId: userId)
                                                    NotificationCenter.default.post(name: .gazeOutfitUnsaved, object: outfit.id)
                                                } else {
                                                    try await SupabaseService.shared.saveOutfit(outfitId: outfit.id, userId: userId)
                                                    NotificationCenter.default.post(name: .gazeOutfitSaved, object: outfit)
                                                }
                                            } catch {
                                                withAnimation(GazeAnimations.springBouncy) { isSaved = wasSaved }
                                            }
                                        }
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                            .font(.system(size: 26, weight: .medium))
                                            .foregroundStyle(isSaved ? Color.gazeAccent : Color.gazeTextSecondary)
                                            .scaleEffect(isSaved ? 1.1 : 1.0)
                                        Text(isSaved ? "Saved" : "Save")
                                            .font(.system(size: 13))
                                            .foregroundStyle(isSaved ? Color.gazeAccent : Color.gazeTextSecondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(Color.gazeCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.gazeBorder, lineWidth: 1)
                            )
                            .padding(.horizontal, 20)

                            // Location tag only
                            HStack(spacing: 10) {
                                TagBadge(icon: "location.fill", label: outfit.city, color: Color.gazeTextSecondary)
                            }
                            .padding(.horizontal, 20)

                            Spacer().frame(height: 40)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(GazeAnimations.springSnappy, value: appeared)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.gazeTextPrimary)
                            .padding(8)
                            .background(Circle().fill(Color.gazeCard.opacity(0.8)))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Save
                        Button {
                            GazeHaptics.light()
                            let wasSaved = isSaved
                            withAnimation(GazeAnimations.springBouncy) { isSaved.toggle() }
                            if let userId = SupabaseManager.shared.currentUserId {
                                Task {
                                    do {
                                        if wasSaved {
                                            try await SupabaseService.shared.unsaveOutfit(outfitId: outfit.id, userId: userId)
                                            NotificationCenter.default.post(name: .gazeOutfitUnsaved, object: outfit.id)
                                        } else {
                                            try await SupabaseService.shared.saveOutfit(outfitId: outfit.id, userId: userId)
                                            NotificationCenter.default.post(name: .gazeOutfitSaved, object: outfit)
                                        }
                                    } catch {
                                        withAnimation(GazeAnimations.springBouncy) { isSaved = wasSaved }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(isSaved ? Color.gazeAccent : Color.gazeTextPrimary)
                                .scaleEffect(isSaved ? 1.1 : 1.0)
                        }

                        // Share
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.gazeTextPrimary)
                        }

                        Menu {
                            if isOwnPost {
                                Button(role: .destructive) {
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete Post", systemImage: "trash")
                                }
                            } else if let postUser = outfit.user {
                                Button(role: .destructive) {
                                    showBlockConfirm = true
                                } label: {
                                    Label("Block @\(postUser.username)", systemImage: "hand.raised.fill")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.gazeTextPrimary)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showUserProfile) {
                if let user = outfit.user { UserProfileView(user: user) }
            }
            .preferredColorScheme(.light)
        .onAppear {
            withAnimation(GazeAnimations.springSnappy) { appeared = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gazeOutfitCommented)) { n in
            if let id = n.object as? UUID, id == outfit.id {
                commentCount += 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gazeCommentDeleted)) { n in
            if let id = n.object as? UUID, id == outfit.id {
                commentCount = max(0, commentCount - 1)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(outfit: outfit)
        }
        .sheet(isPresented: $showComments) {
            CommentsView(outfit: outfit)
        }
        .confirmationDialog(
            "Block @\(outfit.user?.username ?? "this user")?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                guard let currentId = SupabaseManager.shared.currentUserId else { return }
                dismiss()
                Task {
                    do {
                        try await SupabaseService.shared.blockUser(blockerId: currentId, blockedId: outfit.userId)
                        NotificationCenter.default.post(name: .gazeUserBlocked, object: outfit.userId)
                        NotificationCenter.default.post(name: .gazeFollowStateChanged, object: nil)
                    } catch {
                        AppLogger.error("Block user failed from outfit detail", category: .social, properties: ["error": error.localizedDescription])
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to find your profile or posts. They won't be notified.")
        }
        .confirmationDialog("Delete this post?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await SupabaseService.shared.softDeleteOutfit(id: outfit.id)
                        NotificationCenter.default.post(name: .gazeOutfitDeleted, object: outfit.id)
                        await MainActor.run { dismiss() }
                    } catch {
                        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                        AppLogger.error("Outfit delete failed from detail", category: .post, properties: ["outfit_id": outfit.id.uuidString, "error": error.localizedDescription])
                        await MainActor.run {
                            deleteFailedMessage = message
                            showDeleteFailedAlert = true
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Could not delete post", isPresented: $showDeleteFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteFailedMessage)
        }
    }

    private func toggleFollow(user: GazeUser) {
        guard let currentId = SupabaseManager.shared.currentUserId else { return }
        GazeHaptics.medium()
        isFollowingUser.toggle()
        let delta = isFollowingUser ? 1 : -1
        Task {
            do {
                if isFollowingUser {
                    try await SupabaseService.shared.follow(followerId: currentId, followingId: user.id)
                } else {
                    try await SupabaseService.shared.unfollow(followerId: currentId, followingId: user.id)
                }
                NotificationCenter.default.post(name: .gazeFollowingCountChanged, object: delta)
                NotificationCenter.default.post(name: .gazeFollowStateChanged, object: nil)
            } catch {
                isFollowingUser.toggle() // rollback on error
            }
        }
    }
}

private struct DetailStat: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.gazeTextPrimary)
            }
            Text(label)
                .font(GazeType.labelSmall)
                .foregroundStyle(Color.gazeTextMuted)
        }
    }
}

private struct TagBadge: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(GazeType.labelSmall)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(color.opacity(0.1))
                .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
        )
    }
}

// MARK: - Share Sheet

struct ShareSheetView: View {
    let outfit: Outfit
    @Environment(\.dismiss) private var dismiss
    @State private var showActivitySheet = false
    @State private var copiedLink = false

    private var shareText: String {
        var text = outfit.caption
        if let user = outfit.user {
            text += " — @\(user.username) on GAZE"
        }
        return text
    }

    private var shareItems: [Any] {
        var items: [Any] = [shareText]
        if let urlStr = outfit.imageURL, let url = URL(string: urlStr) {
            items.append(url)
        }
        return items
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                ZStack(alignment: .bottomLeading) {
                    OutfitGradientCard(gradientIndex: outfit.gradientIndex, cornerRadius: 20)
                        .frame(height: 220)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(outfit.caption)
                            .font(GazeType.headlineSmall)
                            .foregroundStyle(.white)
                    }
                    .padding(16)
                    .background(
                        LinearGradient(colors: [.clear, Color.black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    )
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    ShareOption(icon: "message.fill", color: Color.gazeSuccess, label: "Share via Messages") {
                        showActivitySheet = true
                    }
                    ShareOption(icon: "camera.fill", color: Color(hex: "#E1306C"), label: "Share to Instagram Story") {
                        showActivitySheet = true
                    }
                    ShareOption(icon: "link", color: Color.gazeIce, label: copiedLink ? "Copied!" : "Copy link") {
                        copyLink()
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 24)
            .background(Color.gazeBackground.ignoresSafeArea())
            .navigationTitle("Share outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.gazeAccent)
                }
            }
            .preferredColorScheme(.light)
            .sheet(isPresented: $showActivitySheet) {
                ActivityShareSheet(items: shareItems)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func copyLink() {
        if let urlStr = outfit.imageURL, let url = URL(string: urlStr) {
            UIPasteboard.general.url = url
        } else {
            UIPasteboard.general.string = shareText
        }
        GazeHaptics.success()
        withAnimation(GazeAnimations.springSnappy) { copiedLink = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ShareOption: View {
    let icon: String
    let color: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(GazeType.bodyMedium)
                    .foregroundStyle(Color.gazeTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.gazeTextMuted)
            }
            .padding(16)
            .background(Color.gazeCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.gazeBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - User Profile Sheet (quick view from detail)

struct UserProfileSheet: View {
    let user: GazeUser
    @State private var isFollowing: Bool
    @State private var followerCount: Int
    @State private var followingCount: Int
    @State private var outfitCount: Int
    @State private var outfits: [Outfit] = []
    @Environment(\.dismiss) private var dismiss

    init(user: GazeUser) {
        self.user = user
        _isFollowing    = State(initialValue: user.isFollowing)
        _followerCount  = State(initialValue: user.followerCount)
        _followingCount = State(initialValue: user.followingCount)
        _outfitCount    = State(initialValue: user.outfitCount)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Avatar header
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: user.avatarColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 150)

                        LinearGradient(
                            colors: [.clear, Color.gazeBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 150)
                    }

                    VStack(spacing: 14) {
                        HStack(alignment: .bottom) {
                            GazeAvatar(user: user, size: 76)
                                .offset(y: -28)
                                .padding(.leading, 20)

                            Spacer()

                            FollowButton(isFollowing: isFollowing) {
                                GazeHaptics.medium()
                                let wasFollowing = isFollowing
                                isFollowing.toggle()
                                followerCount += wasFollowing ? -1 : 1
                                guard let currentId = SupabaseManager.shared.currentUserId else { return }
                                Task {
                                    do {
                                        if wasFollowing { try await SupabaseService.shared.unfollow(followerId: currentId, followingId: user.id) }
                                        else            { try await SupabaseService.shared.follow(followerId: currentId, followingId: user.id) }
                                        let delta = wasFollowing ? -1 : 1
                                        NotificationCenter.default.post(name: .gazeFollowingCountChanged, object: delta)
                                        NotificationCenter.default.post(name: .gazeFollowStateChanged, object: nil)
                                    } catch {
                                        isFollowing = wasFollowing
                                        followerCount += wasFollowing ? 1 : -1
                                    }
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 10)
                        }
                        .padding(.top, -36)

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(user.displayName)
                                    .font(GazeType.headlineLarge)
                                    .foregroundStyle(Color.gazeTextPrimary)
                                if user.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.gazeAccent)
                                }
                            }
                            Text("@\(user.username)")
                                .font(GazeType.bodyMedium)
                                .foregroundStyle(Color.gazeTextSecondary)

                            Text(user.bio)
                                .font(GazeType.bodySmall)
                                .foregroundStyle(Color.gazeTextSecondary)
                                .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                        // Stats
                        HStack(spacing: 0) {
                            StatItem(value: followerCount.shortFormatted, label: "Followers")
                                .frame(maxWidth: .infinity)
                            Divider().frame(height: 28).background(Color.gazeBorder)
                            StatItem(value: followingCount.shortFormatted, label: "Following")
                                .frame(maxWidth: .infinity)
                            Divider().frame(height: 28).background(Color.gazeBorder)
                            StatItem(value: outfits.isEmpty ? "\(outfitCount)" : "\(outfits.count)", label: "Outfits")
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 14)
                        .background(Color.gazeCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.gazeBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)

                        // Grid — only show outfits that have a real image
                        let imageOutfits = outfits.filter { $0.imageURL != nil || MockDataService.shared.localImage(for: $0.id) != nil }
                        if !imageOutfits.isEmpty {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(imageOutfits) { outfit in
                                    Color.clear
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay(OutfitCard(outfit: outfit, cornerRadius: 0).clipped())
                                        .clipped()
                                }
                            }
                        }

                        Spacer().frame(height: 40)
                    }
                }
            }
            .background(Color.gazeBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(GazeType.headlineSmall)
                        .foregroundStyle(Color.gazeAccent)
                }
            }
            .preferredColorScheme(.light)
        }
        .onAppear {
            Task {
                let currentId = SupabaseManager.shared.currentUserId ?? user.id
                async let fetchedOutfits   = SupabaseService.shared.fetchProfileOutfits(userId: user.id, currentUserId: currentId)
                async let fetchedProfile   = SupabaseService.shared.fetchProfile(id: user.id)
                async let fetchedFollowing = SupabaseService.shared.isFollowing(followerId: currentId, followingId: user.id)
                if let fetched = try? await fetchedOutfits { outfits = fetched }
                if let profile = try? await fetchedProfile {
                    let g = profile.toGazeUser()
                    followerCount  = g.followerCount
                    followingCount = g.followingCount
                    outfitCount    = g.outfitCount
                }
                if let following = try? await fetchedFollowing { isFollowing = following }
            }
        }
    }
}
