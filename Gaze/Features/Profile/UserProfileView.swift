import SwiftUI

// MARK: - User Profile View (read-only, for viewing other users)

struct UserProfileView: View {

    let user: GazeUser
    @Environment(\.dismiss) private var dismiss

    @State private var outfits: [Outfit] = []
    @State private var challengeEntries: [ChallengeEntry] = []
    @State private var isLoading = true
    @State private var isFollowing: Bool
    @State private var followerCount: Int
    @State private var followingCount: Int
    @State private var outfitCount: Int
    @State private var activeTab: UserProfileTab = .posts
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var followError: String?
    @State private var showBlockConfirm = false
    @State private var isBlocked = false

    private enum UserProfileTab: String, CaseIterable {
        case posts = "Posts"
        case arena = "Runway"
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    /// Matches posts grid: only outfits with a stored image URL.
    private var displayedPostsStat: Int {
        if isLoading { return outfitCount }
        return outfits.filter { $0.imageURL != nil }.count
    }

    init(user: GazeUser) {
        self.user = user
        _isFollowing = State(initialValue: user.isFollowing)
        _followerCount = State(initialValue: user.followerCount)
        _followingCount = State(initialValue: user.followingCount)
        _outfitCount = State(initialValue: user.outfitCount)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.gazeBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 16)

                        // Avatar + info
                        VStack(spacing: 12) {
                            GazeAvatar(user: user, size: 80)

                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(user.displayName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Color.gazeTextPrimary)
                                    if user.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.gazeAccent)
                                    }
                                }
                                Text("@\(user.username)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.gazeTextSecondary)
                            }

                            if !user.bio.isEmpty {
                                Text(user.bio)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.gazeTextSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }

                            // Stats
                            HStack(spacing: 6) {
                                Text("\(displayedPostsStat) posts")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.gazeTextPrimary)
                                Text("·").foregroundStyle(Color.gazeTextMuted).font(.system(size: 12))
                                Button { showFollowers = true } label: {
                                    Text("\(followerCount.shortFormatted) followers")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.gazeTextPrimary)
                                }
                                .buttonStyle(.plain)
                                Text("·").foregroundStyle(Color.gazeTextMuted).font(.system(size: 12))
                                Button { showFollowing = true } label: {
                                    Text("\(followingCount.shortFormatted) following")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.gazeTextPrimary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 2)

                            // Challenge wins badge
                            if user.challengeWins > 0 {
                                HStack(spacing: 5) {
                                    Text("🏆")
                                        .font(.system(size: 12))
                                    Text("\(user.challengeWins) challenge \(user.challengeWins == 1 ? "win" : "wins")")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(hex: "#D4AF37"))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#D4AF37").opacity(0.12))
                                .clipShape(Capsule())
                                .padding(.top, 2)
                            }

                            // Follow button
                            Button {
                                toggleFollow()
                            } label: {
                                Text(isFollowing ? "Following" : "Follow")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(isFollowing ? Color.gazeTextPrimary : .white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule().fill(isFollowing ? Color.gazeCard : Color.gazeAccent)
                                            .overlay(Capsule().strokeBorder(
                                                isFollowing ? Color.gazeBorder : Color.clear, lineWidth: 1))
                                    )
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .animation(GazeAnimations.springSnappy, value: isFollowing)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                        // Tab switcher
                        HStack(spacing: 0) {
                            ForEach(UserProfileTab.allCases, id: \.self) { tab in
                                Button {
                                    GazeHaptics.selection()
                                    withAnimation(GazeAnimations.springSnappy) { activeTab = tab }
                                } label: {
                                    VStack(spacing: 0) {
                                        Text(tab.rawValue)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(
                                                activeTab == tab
                                                ? Color.gazeTextPrimary
                                                : Color.gazeTextSecondary
                                            )
                                            .padding(.vertical, 12)
                                            .frame(maxWidth: .infinity)
                                        Rectangle()
                                            .fill(activeTab == tab ? Color.gazeAccent : Color.clear)
                                            .frame(height: 1.5)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .overlay(
                            Rectangle().fill(Color.gazeBorder).frame(height: 1),
                            alignment: .bottom
                        )

                        // Photo grid
                        if isLoading {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(0..<6, id: \.self) { _ in
                                    ShimmerView()
                                        .aspectRatio(1, contentMode: .fill)
                                        .frame(minHeight: 120)
                                }
                            }
                            .padding(.top, 2)
                        } else if activeTab == .arena {
                            if challengeEntries.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "trophy")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Color.gazeTextMuted)
                                    Text("No runway entries yet")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.gazeTextSecondary)
                                }
                                .padding(.top, 60)
                            } else {
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(challengeEntries) { entry in
                                        if let outfit = entry.outfit {
                                            NavigationLink(value: outfit) {
                                                Color.clear
                                                    .aspectRatio(1, contentMode: .fit)
                                                    .overlay(
                                                        ZStack(alignment: .bottomLeading) {
                                                            OutfitCard(outfit: outfit, cornerRadius: 0)
                                                                .clipped()
                                                            Text("Wk \(entry.weekNumber)")
                                                                .font(.system(size: 10, weight: .bold))
                                                                .foregroundStyle(.white)
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 3)
                                                                .background(Color.black.opacity(0.55))
                                                                .clipShape(Capsule())
                                                                .padding(5)
                                                        }
                                                    )
                                                    .clipped()
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.top, 2)
                            }
                        } else if outfits.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "camera")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.gazeTextMuted)
                                Text("No outfits yet")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.gazeTextSecondary)
                            }
                            .padding(.top, 60)
                        } else {
                            let imageOutfits = outfits.filter { $0.imageURL != nil }
                            if imageOutfits.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Color.gazeTextMuted)
                                    Text("No outfits yet")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.gazeTextSecondary)
                                }
                                .padding(.top, 60)
                            } else {
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(imageOutfits) { outfit in
                                        NavigationLink(value: outfit) {
                                            Color.clear
                                                .aspectRatio(1, contentMode: .fit)
                                                .overlay(
                                                    OutfitCard(outfit: outfit, cornerRadius: 0)
                                                        .clipped()
                                                )
                                                .clipped()
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.top, 2)
                            }
                        }

                        Spacer().frame(height: 60)
                    }
                }
            }
            .refreshable { await loadOutfitsAsync() }
            .navigationTitle("@\(user.username)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if user.id != SupabaseManager.shared.currentUserId {
                        Menu {
                            Button(role: .destructive) {
                                showBlockConfirm = true
                            } label: {
                                Label(
                                    isBlocked ? "Unblock @\(user.username)" : "Block @\(user.username)",
                                    systemImage: isBlocked ? "hand.raised.slash" : "hand.raised.fill"
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.gazeTextPrimary)
                        }
                    }
                }
            }
            .preferredColorScheme(.light)
        .onAppear {
            isBlocked = SupabaseService.shared.isBlocked(
                blockerId: SupabaseManager.shared.currentUserId ?? UUID(),
                blockedId: user.id
            )
            loadOutfits()
        }
        .confirmationDialog(
            isBlocked ? "Unblock @\(user.username)?" : "Block @\(user.username)?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            if isBlocked {
                Button("Unblock", role: .destructive) { performUnblock() }
            } else {
                Button("Block", role: .destructive) { performBlock() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if !isBlocked {
                Text("They won't be able to find your profile or posts. They won't be notified.")
            }
        }
        .sheet(isPresented: $showFollowers) {
            UserListSheet(title: "Followers", userId: user.id, mode: .followers)
        }
        .sheet(isPresented: $showFollowing) {
            UserListSheet(title: "Following", userId: user.id, mode: .following)
        }
        .alert("Error", isPresented: Binding(
            get: { followError != nil },
            set: { if !$0 { followError = nil } }
        )) {
            Button("OK") { followError = nil }
        } message: {
            Text(followError ?? "")
        }
    }

    private func loadOutfits() {
        Task { await loadOutfitsAsync() }
    }

    private func loadOutfitsAsync() async {
        isLoading = true
        let currentUserId = SupabaseManager.shared.currentUserId ?? user.id
        async let fetchedOutfits = SupabaseService.shared.fetchProfileOutfits(
            userId: user.id, currentUserId: currentUserId)
        async let fetchedEntries = SupabaseService.shared.fetchUserChallengeEntries(userId: user.id)
        async let fetchedFollowing = SupabaseService.shared.isFollowing(
            followerId: currentUserId, followingId: user.id)
        async let fetchedProfile = SupabaseService.shared.fetchProfile(id: user.id)
        outfits = (try? await fetchedOutfits) ?? []
        challengeEntries = (try? await fetchedEntries) ?? []
        isFollowing = (try? await fetchedFollowing) ?? isFollowing
        if let profile = try? await fetchedProfile {
            let refreshed = profile.toGazeUser()
            followerCount = refreshed.followerCount
            followingCount = refreshed.followingCount
            outfitCount = refreshed.outfitCount
        }
        isLoading = false
    }

    private func performBlock() {
        guard let currentId = SupabaseManager.shared.currentUserId else { return }
        isBlocked = true
        if isFollowing {
            isFollowing = false
            followerCount -= 1
        }
        Task {
            do {
                try await SupabaseService.shared.blockUser(blockerId: currentId, blockedId: user.id)
                NotificationCenter.default.post(name: .gazeUserBlocked, object: user.id)
                NotificationCenter.default.post(name: .gazeFollowStateChanged, object: nil)
            } catch {
                isBlocked = false
                followError = "Could not block user. Please try again."
                print("[Block] error: \(error)")
            }
        }
    }

    private func performUnblock() {
        guard let currentId = SupabaseManager.shared.currentUserId else { return }
        isBlocked = false
        Task {
            do {
                try await SupabaseService.shared.unblockUser(blockerId: currentId, blockedId: user.id)
                NotificationCenter.default.post(name: .gazeUserBlocked, object: nil)
            } catch {
                isBlocked = true
                followError = "Could not unblock user. Please try again."
                print("[Unblock] error: \(error)")
            }
        }
    }

    private func toggleFollow() {
        guard let currentId = SupabaseManager.shared.currentUserId else { return }
        GazeHaptics.medium()
        if isFollowing {
            isFollowing = false
            followerCount -= 1
            Task {
                do {
                    try await SupabaseService.shared.unfollow(followerId: currentId, followingId: user.id)
                    NotificationCenter.default.post(name: .gazeFollowingCountChanged, object: -1)
                    NotificationCenter.default.post(name: .gazeFollowStateChanged, object: nil)
                } catch {
                    isFollowing = true
                    followerCount += 1
                    followError = error.localizedDescription
                    print("[Follow] unfollow error: \(error)")
                }
            }
        } else {
            isFollowing = true
            followerCount += 1
            Task {
                do {
                    try await SupabaseService.shared.follow(followerId: currentId, followingId: user.id)
                    NotificationCenter.default.post(name: .gazeFollowingCountChanged, object: 1)
                    NotificationCenter.default.post(name: .gazeFollowStateChanged, object: nil)
                } catch {
                    isFollowing = false
                    followerCount -= 1
                    followError = error.localizedDescription
                    print("[Follow] follow error: \(error)")
                }
            }
        }
    }
}
