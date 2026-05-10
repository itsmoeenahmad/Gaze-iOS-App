import Foundation
import SwiftUI
import Combine

// MARK: - Challenge ViewModel

@MainActor
final class ChallengeViewModel: ObservableObject {

    // MARK: State

    @Published var challenge: ChallengeWeek?
    @Published var feed: [ChallengeSubmission] = []
    @Published var finalists: [ChallengeSubmission] = []
    @Published var isLoading = true
    @Published var error: String?

    // Submit flow
    @Published var pendingImage: UIImage?
    @Published var pendingCaption = ""
    @Published var isDraftSaving = false
    @Published var isConfirming = false
    @Published var showConfirmLockWarning = false
    @Published var showSubmitSheet = false

    private var liveTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        NotificationCenter.default.publisher(for: .gazeChallengeEntryDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in Task { await self?.reload() } }
            .store(in: &cancellables)
    }

    deinit { liveTask?.cancel() }

    // MARK: - Load

    func load() {
        Task { await reload() }
        startLiveRefresh()
    }

    func reload() async {
        isLoading = true
        do {
            challenge = try await ChallengeService.shared.loadActiveChallenge()
            guard let ch = challenge else { isLoading = false; return }

            switch ch.status {
            case .finals:
                finalists = try await ChallengeService.shared.loadFinalsFeed(challengeId: ch.id)
            case .collecting, .voting:
                feed = try await ChallengeService.shared.loadChallengeFeed(challengeId: ch.id)
            case .closed, .archived:
                break
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func startLiveRefresh() {
        liveTask?.cancel()
        liveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await silentRefreshCounts()
            }
        }
    }

    private func silentRefreshCounts() async {
        guard let ch = challenge else { return }

        if ch.status == .finals {
            guard let freshFinals = try? await ChallengeService.shared.loadFinalsFeed(challengeId: ch.id)
            else { return }
            for item in freshFinals {
                if let idx = finalists.firstIndex(where: { $0.id == item.id }) {
                    finalists[idx].finalsVoteCount = item.finalsVoteCount
                    finalists[idx].likeCount = item.likeCount
                }
            }
            return
        }

        guard let fresh = try? await ChallengeService.shared.loadChallengeFeed(challengeId: ch.id)
        else { return }
        for item in fresh {
            if let idx = feed.firstIndex(where: { $0.id == item.id }) {
                feed[idx].voteCount = item.voteCount
                feed[idx].likeCount = item.likeCount
            }
        }
        feed.sort { $0.voteCount > $1.voteCount }
    }

    // MARK: - Submit flow

    /// Step 1: upload photo + save draft, then show confirmation sheet
    func saveDraft() async {
        guard let image = pendingImage,
              let ch = challenge,
              let uid = SupabaseManager.shared.currentUserId else { return }

        isDraftSaving = true
        do {
            let url = try await ChallengeService.shared.uploadChallengePhoto(image, userId: uid)
            let caption = pendingCaption.trimmingCharacters(in: .whitespaces)
            let draft = try await ChallengeService.shared.saveDraft(
                challengeId: ch.id,
                imageUrl: url,
                caption: caption.isEmpty ? nil : caption
            )
            var updated = ch
            updated.mySubmission = draft
            challenge = updated
            showConfirmLockWarning = true
        } catch {
            self.error = error.localizedDescription
        }
        isDraftSaving = false
    }

    /// Step 2: confirm (lock) the draft
    func confirmSubmission() async {
        guard let sub = challenge?.mySubmission else { return }
        isConfirming = true
        do {
            let confirmed = try await ChallengeService.shared.confirmSubmission(submissionId: sub.id)
            if var updated = challenge {
                updated.mySubmission = confirmed
                challenge = updated
            }
            showConfirmLockWarning = false
            showSubmitSheet = false
            pendingImage = nil
            pendingCaption = ""
            GazeHaptics.success()
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
        isConfirming = false
    }

    func cancelDraft() {
        pendingImage = nil
        pendingCaption = ""
        showConfirmLockWarning = false
        showSubmitSheet = false
        // draft row stays in DB as pending (fine — it'll be overwritten next time)
    }

    // MARK: - Vote

    func vote(submission: ChallengeSubmission) {
        guard submission.isVotingWindowOpen,
              !submission.hasVoted,
              submission.userId != SupabaseManager.shared.currentUserId else { return }

        GazeHaptics.medium()

        // Optimistic
        if let idx = feed.firstIndex(where: { $0.id == submission.id }) {
            feed[idx].hasVoted = true
            feed[idx].voteCount += 1
            feed.sort { $0.voteCount > $1.voteCount }
        }

        Task {
            do {
                try await ChallengeService.shared.voteOnSubmission(submissionId: submission.id)
            } catch {
                // Rollback
                if let idx = feed.firstIndex(where: { $0.id == submission.id }) {
                    feed[idx].hasVoted = false
                    feed[idx].voteCount = max(0, feed[idx].voteCount - 1)
                    feed.sort { $0.voteCount > $1.voteCount }
                }
            }
        }
    }

    func voteInFinals(submission: ChallengeSubmission) {
        guard let ch = challenge,
              challenge?.myFinalsVoteId == nil,
              submission.userId != SupabaseManager.shared.currentUserId else { return }

        GazeHaptics.medium()

        // Optimistic
        var updated = ch
        updated.myFinalsVoteId = submission.id
        challenge = updated
        if let idx = finalists.firstIndex(where: { $0.id == submission.id }) {
            finalists[idx].userHasVotedFinals = true
            finalists[idx].finalsVoteCount = (finalists[idx].finalsVoteCount ?? 0) + 1
        }

        Task {
            do {
                try await ChallengeService.shared.voteInFinals(
                    challengeId: ch.id, submissionId: submission.id)
            } catch {
                if var rolledBack = self.challenge {
                    rolledBack.myFinalsVoteId = nil
                    self.challenge = rolledBack
                }
                if let idx = finalists.firstIndex(where: { $0.id == submission.id }) {
                    finalists[idx].userHasVotedFinals = false
                    finalists[idx].finalsVoteCount = max(0, (finalists[idx].finalsVoteCount ?? 1) - 1)
                }
            }
        }
    }

    // MARK: - Like

    func toggleLike(submission: ChallengeSubmission) {
        guard let idx = feed.firstIndex(where: { $0.id == submission.id }),
              let uid = SupabaseManager.shared.currentUserId else { return }
        let wasLiked = feed[idx].hasLiked
        GazeHaptics.light()

        feed[idx].hasLiked = !wasLiked
        feed[idx].likeCount += wasLiked ? -1 : 1

        Task {
            do {
                if wasLiked {
                    try await ChallengeService.shared.unlikeSubmission(submissionId: submission.id, userId: uid)
                } else {
                    try await ChallengeService.shared.likeSubmission(submissionId: submission.id, userId: uid)
                }
            } catch {
                // Rollback
                if let i = feed.firstIndex(where: { $0.id == submission.id }) {
                    feed[i].hasLiked = wasLiked
                    feed[i].likeCount += wasLiked ? 1 : -1
                }
            }
        }
    }
}
