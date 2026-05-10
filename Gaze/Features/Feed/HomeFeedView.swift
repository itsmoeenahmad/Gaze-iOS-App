import SwiftUI
import Combine

// MARK: - Home Feed View (BeReal-style friends feed)

struct HomeFeedView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @StateObject private var vm = HomeFeedViewModel()
    @State private var showFriends = false
    @State private var commentOutfit: Outfit? = nil
    @State private var pendingRequestCount: Int = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.gazeBackground.ignoresSafeArea()

            if vm.isLoading {
                HomeFeedLoadingView()
                    .padding(.top, 100)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        if vm.hasError {
                            VStack(spacing: 12) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.gazeTextMuted)
                                Text("Couldn't load feed")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.gazeTextSecondary)
                                Button("Try again") { vm.load() }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.gazeAccent)
                            }
                            .padding(.top, 80)
                            .frame(maxWidth: .infinity)
                        } else if vm.outfits.isEmpty {
                            HomeFeedEmptyView(
                                mode: vm.feedMode,
                                onFindFriends: { showFriends = true }
                            )
                        } else {
                            ForEach(vm.outfits) { outfit in
                                HomeFeedCard(
                                    outfit: outfit,
                                    onComment: { commentOutfit = outfit },
                                    onFire: { vm.toggleFire(outfit: outfit) },
                                    onSave: { vm.toggleSave(outfit: outfit) }
                                )
                                .padding(.bottom, 24)
                                .onAppear {
                                    if outfit.id == vm.outfits.last?.id {
                                        vm.loadMore()
                                    }
                                }
                            }
                            if vm.isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                            }
                            Spacer().frame(height: 80)
                        }
                    }
                }
                .refreshable {
                    await vm.refresh()
                }
                .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 140) }
            }

            // Top bar
            HomeFeedTopBar(
                feedMode: $vm.feedMode,
                onFriendsTap: { showFriends = true },
                onNotificationsTap: { appVM.showNotifications = true },
                pendingCount: pendingRequestCount,
                notificationCount: appVM.notificationCount
            )
        }
        .onAppear {
            if vm.outfits.isEmpty { vm.load() }
            fetchPendingCount()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            fetchPendingCount()
            Task { await appVM.refreshNotificationCount() }
        }
        .onChange(of: showFriends) { _, open in
            if !open {
                fetchPendingCount()
                Task { await vm.refresh() }
            }
        }
        .onChange(of: vm.feedMode) { _, _ in
            GazeHaptics.selection()
        }
        .sheet(item: $commentOutfit) { outfit in
            CommentsView(outfit: outfit)
        }
        .sheet(isPresented: $showFriends) {
            FriendsView()
        }
    }

    private func fetchPendingCount() {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        Task {
            let requests = (try? await SupabaseService.shared.fetchIncomingRequests(userId: userId)) ?? []
            await MainActor.run { pendingRequestCount = requests.count }
        }
    }
}

// MARK: - Top Bar

private struct HomeFeedTopBar: View {
    @Binding var feedMode: FeedMode
    let onFriendsTap: () -> Void
    let onNotificationsTap: () -> Void
    let pendingCount: Int
    let notificationCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("GAZE")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.gazeTextMuted)
                    .tracking(4)

                Spacer()

                HStack(spacing: 16) {
                    Button(action: onNotificationsTap) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.gazeTextPrimary)

                            if notificationCount > 0 {
                                ZStack {
                                    Circle()
                                        .fill(Color.gazeFire)
                                        .frame(width: 16, height: 16)
                                    Text(notificationCount > 9 ? "9+" : "\(notificationCount)")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(.white)
                                }
                                .offset(x: 8, y: -6)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(GazePressStyle())

                    Button(action: onFriendsTap) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(Color.gazeTextPrimary)

                            if pendingCount > 0 {
                                ZStack {
                                    Circle()
                                        .fill(Color.gazeFire)
                                        .frame(width: 16, height: 16)
                                    Text(pendingCount > 9 ? "9+" : "\(pendingCount)")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(.white)
                                }
                                .offset(x: 6, y: -4)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(GazePressStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)

            // Feed mode toggle
            HStack(spacing: 0) {
                ForEach(FeedMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(GazeAnimations.springSnappy) { feedMode = mode }
                    } label: {
                        VStack(spacing: 0) {
                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(feedMode == mode ? Color.gazeTextPrimary : Color.gazeTextSecondary)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                            Rectangle()
                                .fill(feedMode == mode ? Color.gazeAccent : Color.clear)
                                .frame(height: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(Rectangle().fill(Color.gazeBorder).frame(height: 1), alignment: .bottom)
        }
        .background(Color.gazeBackground.opacity(0.97).ignoresSafeArea(edges: .top))
    }
}

// MARK: - Feed Card

private struct HomeFeedCard: View {
    let outfit: Outfit
    let onComment: () -> Void
    let onFire: () -> Void
    let onSave: () -> Void

    @State private var isLiked: Bool
    @State private var isSaved: Bool
    @State private var likeCount: Int

    init(outfit: Outfit, onComment: @escaping () -> Void,
         onFire: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.outfit = outfit
        self.onComment = onComment
        self.onFire = onFire
        self.onSave = onSave
        _isLiked = State(initialValue: outfit.isRatedByCurrentUser)
        _isSaved = State(initialValue: outfit.isSaved)
        _likeCount = State(initialValue: outfit.fireCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-width photo — NavigationLink push to detail
            NavigationLink(value: outfit) {
                GeometryReader { geo in
                    OutfitCard(outfit: outfit, cornerRadius: 0)
                        .frame(width: geo.size.width, height: geo.size.width * 1.25)
                        .clipped()
                }
                .aspectRatio(4/5, contentMode: .fit)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // User row
            HStack(spacing: 10) {
                if let user = outfit.user {
                    NavigationLink(value: user) {
                        HStack(spacing: 10) {
                            GazeAvatar(user: user, size: 32)

                            VStack(alignment: .leading, spacing: 1) {
                                Text("@\(user.username)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.gazeTextPrimary)
                                Text(outfit.timeAgoString)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.gazeTextSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if outfit.visibility == .friends {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Friends")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.gazeTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.gazeCard))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if !outfit.caption.isEmpty {
                Text(outfit.caption)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.gazeTextPrimary)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }

            // Action row
            HStack(spacing: 0) {
                // Heart / Like
                HeartLikeButton(isLiked: $isLiked, count: likeCount, size: 20) {
                    likeCount += isLiked ? 1 : -1
                    onFire()
                }

                Spacer().frame(width: 24)

                // Comment
                Button(action: onComment) {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color.gazeTextSecondary)
                        Text("\(outfit.commentCount)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.gazeTextSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(GazePressStyle())

                Spacer()

                // Save / Bookmark
                Button {
                    GazeHaptics.light()
                    withAnimation(GazeAnimations.springBouncy) { isSaved.toggle() }
                    onSave()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSaved ? Color.gazeAccent : Color.gazeTextSecondary)
                        .scaleEffect(isSaved ? 1.1 : 1.0)
                        .contentShape(Rectangle())
                }
                .buttonStyle(GazePressStyle(scale: 0.88))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(Color.gazeBackground)
        .onChange(of: outfit.isSaved) { _, newValue in isSaved = newValue }
        .onChange(of: outfit.isRatedByCurrentUser) { _, newValue in isLiked = newValue }
        .onChange(of: outfit.fireCount) { _, newValue in likeCount = newValue }
    }
}

// MARK: - Empty State

private struct HomeFeedEmptyView: View {
    let mode: FeedMode
    let onFindFriends: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: mode == .friends ? "person.2" : "person.crop.circle.badge.plus")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(Color.gazeTextMuted)

                VStack(spacing: 8) {
                    Text(mode == .friends ? "Add friends to see their fits" : "Follow people to see their fits")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.gazeTextPrimary)
                    Text(mode == .friends
                         ? "Mutual follows show up here."
                         : "Posts from everyone you follow appear here.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.gazeTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                Button(action: onFindFriends) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Find People")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(Color.gazeAccent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Loading State

private struct HomeFeedLoadingView: View {
    var body: some View {
        VStack(spacing: 24) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    ShimmerView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    HStack(spacing: 10) {
                        ShimmerView()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        ShimmerView()
                            .frame(width: 100, height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.horizontal, 0)
    }
}
