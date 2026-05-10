import SwiftUI

// MARK: - Comments View

struct CommentsView: View {

    let outfit: Outfit
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [Comment] = []
    @State private var newComment: String = ""
    @FocusState private var isFocused: Bool
    @State private var appeared = false
    @State private var isPosting = false
    @State private var showError = false
    @State private var commentToDelete: Comment? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gazeBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if comments.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 40, weight: .thin))
                                .foregroundStyle(Color.gazeTextMuted)
                            Text("No comments yet")
                                .font(GazeType.headlineSmall)
                                .foregroundStyle(Color.gazeTextSecondary)
                            Text("Be the first to say something")
                                .font(GazeType.bodySmall)
                                .foregroundStyle(Color.gazeTextMuted)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(comments.enumerated()), id: \.element.id) { idx, comment in
                                    CommentRow(comment: comment) {
                                        toggleLike(id: comment.id)
                                    }
                                    .contextMenu {
                                        if comment.user?.id == SupabaseManager.shared.currentUserId {
                                            Button(role: .destructive) {
                                                commentToDelete = comment
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 10)
                                    .animation(GazeAnimations.spring.delay(Double(idx) * 0.04), value: appeared)

                                    if idx < comments.count - 1 {
                                        Divider()
                                            .background(Color.gazeBorder)
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .refreshable { await loadComments() }
                    }

                    // Input bar
                    VStack(spacing: 0) {
                        Divider().background(Color.gazeBorder)

                        HStack(spacing: 12) {
                            TextField(
                                "",
                                text: $newComment,
                                prompt: Text("Add a comment…").foregroundStyle(Color.gazeTextMuted)
                            )
                            .font(GazeType.bodyMedium)
                            .foregroundStyle(Color.gazeTextPrimary)
                            .focused($isFocused)
                            .submitLabel(.send)
                            .onSubmit { postComment() }

                            Button(action: postComment) {
                                Text("Post")
                                    .font(GazeType.labelLarge)
                                    .foregroundStyle(newComment.isEmpty ? Color.gazeTextMuted : Color.gazeAccent)
                            }
                            .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty)
                            .contentShape(Rectangle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.gazeCard)
                    }
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.gazeAccent)
                }
            }
            .preferredColorScheme(.light)
            .alert("Couldn't post comment", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Something went wrong. Please try again.")
            }
            .confirmationDialog("Delete comment?", isPresented: Binding(
                get: { commentToDelete != nil },
                set: { if !$0 { commentToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let comment = commentToDelete {
                        performDeleteComment(comment)
                    }
                }
                Button("Cancel", role: .cancel) { commentToDelete = nil }
            }
        }
        .onAppear {
            Task {
                await loadComments()
                withAnimation(GazeAnimations.spring.delay(0.1)) { appeared = true }
            }
        }
    }

    private func loadComments() async {
        AppLogger.debug("Loading comments", category: .comments, properties: ["outfit_id": outfit.id.uuidString])
        let userId = SupabaseManager.shared.currentUserId
        let fetched = (try? await SupabaseService.shared.fetchComments(
            outfitId: outfit.id, currentUserId: userId)) ?? []
        comments = fetched
        if fetched.isEmpty {
            AppLogger.debug("No comments returned", category: .comments, properties: ["outfit_id": outfit.id.uuidString])
        } else {
            AppLogger.info("Comments loaded", category: .comments, properties: ["outfit_id": outfit.id.uuidString, "count": "\(fetched.count)"])
        }
    }

    private func postComment() {
        let trimmed = newComment.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isPosting else { return }
        GazeHaptics.light()
        newComment = ""
        isPosting = true

        guard let userId = SupabaseManager.shared.currentUserId else {
            AppLogger.warning("Posting comment without auth — using mock user", category: .comments)
            let comment = Comment(
                id: UUID(), user: MockDataService.shared.currentUser,
                text: trimmed, timestamp: Date(), isLiked: false, likeCount: 0
            )
            withAnimation(GazeAnimations.spring) { comments.append(comment) }
            isPosting = false
            return
        }

        Task {
            do {
                let posted = try await SupabaseService.shared.addComment(
                    outfitId: outfit.id, userId: userId, text: trimmed)
                withAnimation(GazeAnimations.spring) { comments.append(posted) }
                NotificationCenter.default.post(name: .gazeOutfitCommented, object: outfit.id)
            } catch {
                AppLogger.error("Comment post failed", category: .comments, properties: ["outfit_id": outfit.id.uuidString, "error": error.localizedDescription])
                newComment = trimmed
                showError = true
            }
            isPosting = false
        }
    }

    private func toggleLike(id: UUID) {
        guard let idx = comments.firstIndex(where: { $0.id == id }),
              let userId = SupabaseManager.shared.currentUserId else { return }
        GazeHaptics.light()
        let nowLiked = !comments[idx].isLiked
        withAnimation(GazeAnimations.springBouncy) {
            comments[idx].isLiked = nowLiked
            comments[idx].likeCount += nowLiked ? 1 : -1
        }
        Task {
            do {
                if nowLiked {
                    try await SupabaseService.shared.likeComment(commentId: id, userId: userId)
                } else {
                    try await SupabaseService.shared.unlikeComment(commentId: id, userId: userId)
                }
                AppLogger.debug("Comment like toggled", category: .comments, properties: ["comment_id": id.uuidString, "liked": "\(nowLiked)"])
            } catch {
                AppLogger.error("Comment like toggle failed, rolling back", category: .comments, properties: ["comment_id": id.uuidString, "error": error.localizedDescription])
                if let rollbackIdx = comments.firstIndex(where: { $0.id == id }) {
                    withAnimation(GazeAnimations.springBouncy) {
                        comments[rollbackIdx].isLiked = !nowLiked
                        comments[rollbackIdx].likeCount += nowLiked ? -1 : 1
                    }
                }
            }
        }
    }

    private func performDeleteComment(_ comment: Comment) {
        withAnimation(GazeAnimations.spring) {
            comments.removeAll { $0.id == comment.id }
        }
        GazeHaptics.medium()
        Task {
            do {
                try await SupabaseService.shared.deleteComment(commentId: comment.id, outfitId: outfit.id)
                NotificationCenter.default.post(name: .gazeCommentDeleted, object: outfit.id)
            } catch {
                AppLogger.error("Comment delete failed, restoring", category: .comments, properties: ["comment_id": comment.id.uuidString, "error": error.localizedDescription])
                withAnimation(GazeAnimations.spring) {
                    comments.append(comment)
                    comments.sort { $0.timestamp < $1.timestamp }
                }
            }
        }
    }

}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: Comment
    let onLike: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let user = comment.user {
                GazeAvatar(user: user, size: 36)
            } else {
                Circle()
                    .fill(Color.gazeCard)
                    .frame(width: 36, height: 36)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("@\(comment.user?.username ?? "user")")
                        .font(GazeType.labelLarge)
                        .foregroundStyle(Color.gazeTextPrimary)
                    Text(comment.timestamp.timeAgoString)
                        .font(GazeType.labelSmall)
                        .foregroundStyle(Color.gazeTextMuted)
                }
                Text(comment.text)
                    .font(GazeType.bodyMedium)
                    .foregroundStyle(Color.gazeTextSecondary)
                    .lineSpacing(2)
            }

            Spacer()

            // Like button
            Button(action: onLike) {
                VStack(spacing: 3) {
                    Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(comment.isLiked ? Color.gazeFire : Color.gazeTextMuted)
                        .scaleEffect(comment.isLiked ? 1.15 : 1.0)
                    if comment.likeCount > 0 {
                        Text("\(comment.likeCount)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(comment.isLiked ? Color.gazeFire : Color.gazeTextMuted)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
