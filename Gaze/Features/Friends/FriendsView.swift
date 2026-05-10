import SwiftUI

// MARK: - Friends View

struct FriendsView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var friends: [GazeUser] = []
    @State private var incomingRequests: [FriendRequest] = []
    @State private var sentPendingIds: Set<UUID> = []
    @State private var searchResults: [GazeUser] = []
    @State private var isSearching = false
    @State private var selectedUser: GazeUser? = nil
    @State private var friendToRemove: GazeUser? = nil

    private var currentUserId: UUID? { SupabaseManager.shared.currentUserId }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gazeBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Search bar
                        FriendsSearchBar(text: $searchText)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .onChange(of: searchText) { _, query in
                                updateSearch(query: query)
                            }

                        if !searchText.isEmpty {
                            // Search results
                            FriendsSectionHeader(title: "RESULTS")

                            if isSearching {
                                ProgressView()
                                    .padding(.vertical, 32)
                                    .frame(maxWidth: .infinity)
                            } else if searchResults.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "person.slash")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Color.gazeTextMuted)
                                    Text("No users found")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.gazeTextSecondary)
                                }
                                .padding(.vertical, 32)
                                .frame(maxWidth: .infinity)
                            } else {
                                ForEach(searchResults) { user in
                                    let isRequested = sentPendingIds.contains(user.id)
                                    FriendUserRow(
                                        user: user,
                                        rowType: isRequested ? .requested : .add,
                                        onPrimary: isRequested ? nil : { sendRequest(user) },
                                        onTapRow: { selectedUser = user }
                                    )
                                }
                            }
                        } else {
                            // Incoming requests section
                            if !incomingRequests.isEmpty {
                                FriendsSectionHeader(title: "REQUESTS · \(incomingRequests.count)")

                                ForEach(incomingRequests) { request in
                                    if let fromUser = request.fromUser {
                                        FriendUserRow(
                                            user: fromUser,
                                            rowType: .request,
                                            onPrimary: { acceptRequest(request) },
                                            onSecondary: { declineRequest(request) },
                                            onTapRow: { selectedUser = fromUser }
                                        )
                                    }
                                }
                            }

                            // Friends list (mutual follows)
                            FriendsSectionHeader(title: "FRIENDS · \(friends.count)")

                            if friends.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "person.2")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Color.gazeTextMuted)
                                    Text("No friends yet")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.gazeTextSecondary)
                                    Text("Search by username to find people you know")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.gazeTextMuted)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .padding(.vertical, 32)
                                .frame(maxWidth: .infinity)
                            } else {
                                ForEach(friends) { user in
                                    FriendUserRow(user: user, rowType: .friend, onPrimary: nil,
                                                  onTapRow: { selectedUser = user })
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                friendToRemove = user
                                            } label: {
                                                Label("Remove", systemImage: "person.fill.xmark")
                                            }
                                        }
                                }
                            }
                        }

                        Spacer().frame(height: 60)
                    }
                }
                .refreshable { await refreshAllAsync() }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.gazeAccent)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedUser != nil },
                set: { if !$0 { selectedUser = nil } }
            )) {
                if let user = selectedUser { UserProfileView(user: user) }
            }
            .confirmationDialog(
                "Remove Friend",
                isPresented: Binding(
                    get: { friendToRemove != nil },
                    set: { if !$0 { friendToRemove = nil } }
                ),
                presenting: friendToRemove
            ) { user in
                Button("Remove", role: .destructive) {
                    removeFriend(user)
                }
                Button("Cancel", role: .cancel) {
                    friendToRemove = nil
                }
            } message: { user in
                Text("Remove @\(user.username) from your friends? They will need to send a new friend request to reconnect.")
            }
            .preferredColorScheme(.light)
        }
        .onAppear { loadAll() }
    }

    // MARK: - Load

    private func loadAll() {
        Task { await refreshAllAsync() }
    }

    @MainActor
    private func refreshAllAsync() async {
        guard let userId = currentUserId else { return }
        AppLogger.debug("Refreshing friends data", category: .social)
        async let friendsTask = SupabaseService.shared.fetchFriends(currentUserId: userId)
        async let requestsTask = SupabaseService.shared.fetchIncomingRequests(userId: userId)
        async let pendingTask = SupabaseService.shared.fetchSentPendingIds(fromUserId: userId)
        friends = (try? await friendsTask) ?? []
        incomingRequests = (try? await requestsTask) ?? []
        sentPendingIds = (try? await pendingTask) ?? []
        AppLogger.info("Friends data refreshed", category: .social, properties: ["friends": "\(friends.count)", "incoming_requests": "\(incomingRequests.count)", "sent_pending": "\(sentPendingIds.count)"])
    }

    private func updateSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { searchResults = []; return }
        isSearching = true
        Task {
            let results = (try? await SupabaseService.shared.searchUsers(query: trimmed)) ?? []
            let friendIds = Set(friends.map { $0.id })
            searchResults = results.filter { $0.id != currentUserId && !friendIds.contains($0.id) }
            isSearching = false
            AppLogger.debug("User search completed", category: .social, properties: ["query_length": "\(trimmed.count)", "results": "\(searchResults.count)"])
        }
    }

    // MARK: - Actions

    private func sendRequest(_ user: GazeUser) {
        guard let currentId = currentUserId else { return }
        GazeHaptics.medium()
        AppLogger.info("Sending friend request", category: .social, properties: ["to_user": user.id.uuidString])
        withAnimation(GazeAnimations.spring) {
            _ = sentPendingIds.insert(user.id)
        }
        Task {
            do {
                try await SupabaseService.shared.sendFriendRequest(fromUserId: currentId, toUserId: user.id)
            } catch {
                AppLogger.error("Friend request send failed, rolling back", category: .social, properties: ["to_user": user.id.uuidString, "error": error.localizedDescription])
                withAnimation(GazeAnimations.spring) {
                    sentPendingIds.remove(user.id)
                }
            }
        }
    }

    private func acceptRequest(_ request: FriendRequest) {
        guard let currentId = currentUserId else { return }
        GazeHaptics.success()
        AppLogger.info("Accepting friend request", category: .social, properties: ["from_user": request.fromUserId.uuidString])
        withAnimation(GazeAnimations.spring) {
            incomingRequests.removeAll { $0.id == request.id }
            if let fromUser = request.fromUser {
                friends.insert(fromUser, at: 0)
            }
        }
        Task {
            do {
                try await SupabaseService.shared.acceptFriendRequest(fromUserId: request.fromUserId, toUserId: currentId)
                AppLogger.info("Friend request accepted", category: .social, properties: ["from_user": request.fromUserId.uuidString])
            } catch {
                AppLogger.error("Friend request accept failed, rolling back", category: .social, properties: ["from_user": request.fromUserId.uuidString, "error": error.localizedDescription])
                withAnimation(GazeAnimations.spring) {
                    friends.removeAll { $0.id == request.fromUserId }
                    if !incomingRequests.contains(where: { $0.id == request.id }) {
                        incomingRequests.append(request)
                    }
                }
            }
            await refreshAllAsync()
        }
    }

    private func declineRequest(_ request: FriendRequest) {
        guard let currentId = currentUserId else { return }
        GazeHaptics.light()
        AppLogger.info("Declining friend request", category: .social, properties: ["from_user": request.fromUserId.uuidString])
        withAnimation(GazeAnimations.spring) {
            incomingRequests.removeAll { $0.id == request.id }
        }
        Task {
            do {
                try await SupabaseService.shared.declineFriendRequest(fromUserId: request.fromUserId, toUserId: currentId)
            } catch {
                AppLogger.error("Friend request decline failed", category: .social, properties: ["from_user": request.fromUserId.uuidString, "error": error.localizedDescription])
            }
        }
    }

    private func removeFriend(_ user: GazeUser) {
        guard let currentId = currentUserId else { return }
        GazeHaptics.medium()
        AppLogger.info("Removing friend", category: .social, properties: ["friend_id": user.id.uuidString])
        withAnimation(GazeAnimations.spring) {
            friends.removeAll { $0.id == user.id }
        }
        Task {
            do {
                try await SupabaseService.shared.unfollow(followerId: currentId, followingId: user.id)
                try await SupabaseService.shared.unfollow(followerId: user.id, followingId: currentId)
                AppLogger.info("Friend removed (both follow directions)", category: .social, properties: ["friend_id": user.id.uuidString])
            } catch {
                AppLogger.error("Friend removal failed, rolling back", category: .social, properties: ["friend_id": user.id.uuidString, "error": error.localizedDescription])
                withAnimation(GazeAnimations.spring) {
                    if !friends.contains(where: { $0.id == user.id }) {
                        friends.append(user)
                    }
                }
            }
        }
    }
}

// MARK: - Search Bar

private struct FriendsSearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.gazeTextMuted)

            TextField("", text: $text,
                      prompt: Text("Search by @username or name")
                          .foregroundStyle(Color.gazeTextMuted))
                .font(.system(size: 14))
                .foregroundStyle(Color.gazeTextPrimary)
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.gazeTextMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.gazeCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    focused ? Color.gazeAccent.opacity(0.4) : Color.gazeBorder,
                    lineWidth: 1
                )
        )
        .animation(GazeAnimations.fast, value: focused)
    }
}

// MARK: - Section Header

private struct FriendsSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.gazeTextMuted)
                .tracking(1.5)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }
}

// MARK: - User Row

private enum FriendRowType {
    case add
    case requested
    case request
    case friend
}

private struct FriendUserRow: View {
    let user: GazeUser
    let rowType: FriendRowType
    var onPrimary: (() -> Void)? = nil
    var onSecondary: (() -> Void)? = nil
    var onTapRow: (() -> Void)? = nil

    var body: some View {
        Button {
            onTapRow?()
        } label: {
            HStack(spacing: 12) {
                GazeAvatar(user: user, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("@\(user.username)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.gazeTextPrimary)
                    if !user.city.isEmpty {
                        Text(user.city)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gazeTextSecondary)
                    }
                }

                Spacer()

                switch rowType {
                case .add:
                    Button {
                        onPrimary?()
                    } label: {
                        Text("Add")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.gazeAccent))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)

                case .requested:
                    Text("Requested")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.gazeTextSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(Color.gazeCard)
                                .overlay(Capsule().strokeBorder(Color.gazeBorder, lineWidth: 1))
                        )

                case .request:
                    HStack(spacing: 8) {
                        Button {
                            onPrimary?()
                        } label: {
                            Text("Accept")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.gazeAccent))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            onSecondary?()
                        } label: {
                            Text("Decline")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.gazeTextSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(Color.gazeCard)
                                        .overlay(Capsule().strokeBorder(Color.gazeBorder, lineWidth: 1))
                                )
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                case .friend:
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.gazeSuccess)
                        Text("Friends")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.gazeSuccess)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
