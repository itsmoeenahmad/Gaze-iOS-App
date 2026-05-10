import SwiftUI
import PhotosUI
import Foundation
import Combine

// MARK: - Root Challenge View

struct ChallengeView: View {

    @StateObject private var vm = ChallengeViewModel()
    @EnvironmentObject private var appVM: AppViewModel
    @State private var showInfoSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.gazeBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if vm.isLoading {
                        ChallengeSkeletonView()
                            .padding(.horizontal, 16)
                    } else if let ch = vm.challenge {
                        VStack(spacing: 16) {
                            ChallengeThemeBanner(challenge: ch) {
                                vm.showSubmitSheet = true
                            }
                            .padding(.horizontal, 16)
                            .onTapGesture { showInfoSheet = true }

                            switch ch.status {
                            case .collecting, .voting:
                                ChallengeFeedSection(
                                    feed: vm.feed,
                                    challenge: ch,
                                    onVote: { vm.vote(submission: $0) },
                                    onLike: { vm.toggleLike(submission: $0) }
                                )
                            case .finals:
                                ChallengeFinalsSection(
                                    finalists: vm.finalists,
                                    challenge: ch,
                                    onVote: { id in
                                        if let sub = vm.finalists.first(where: { $0.id == id }) {
                                            vm.voteInFinals(submission: sub)
                                        }
                                    }
                                )
                            case .closed, .archived:
                                ChallengeEmptyFeed(challengeStatus: ch.status)
                            }

                            Spacer().frame(height: 100)
                        }
                    } else {
                        // No active challenge
                        VStack(spacing: 12) {
                            Image(systemName: "trophy")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.gazeTextMuted)
                            Text("No active challenge this week.")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.gazeTextSecondary)
                        }
                        .padding(.top, 80)
                    }
                }
            }
            .refreshable { await vm.reload() }
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 106) }

            ChallengeTopBar()
        }
        .onAppear { vm.load() }
        .sheet(isPresented: $vm.showSubmitSheet) {
            ChallengeSubmitSheet()
                .environmentObject(vm)
                .environmentObject(appVM)
        }
        .sheet(isPresented: $showInfoSheet) {
            if let ch = vm.challenge {
                ChallengeInfoSheet(challenge: ch) {
                    showInfoSheet = false
                    vm.showSubmitSheet = true
                }
            }
        }
    }
}

// MARK: - Top Bar

private struct ChallengeTopBar: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#D4AF37"))
                Text("Challenge")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.gazeTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 12)
            .background(Color.gazeBackground.opacity(0.97))
            Divider().background(Color.gazeBorder)
        }
    }
}

// MARK: - Theme Banner

private struct ChallengeThemeBanner: View {
    let challenge: ChallengeWeek
    let onSubmit: () -> Void

    @State private var timeLeft = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: challenge.themeGradientStart),
                Color(hex: challenge.themeGradientEnd)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(gradient)
                .frame(height: 200)

            Circle().fill(Color.white.opacity(0.06))
                .frame(width: 180, height: 180).offset(x: 180, y: -60)
            Circle().fill(Color.white.opacity(0.04))
                .frame(width: 120, height: 120).offset(x: 250, y: 30)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("WEEK \(challenge.isoWeek)")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(2)

                    HStack(spacing: 3) {
                        Text("🏆").font(.system(size: 9))
                        Text("$100 prize")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#D4AF37"))
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.black.opacity(0.25))
                    .clipShape(Capsule())

                    Spacer()

                    // Status pill
                    Text(statusLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(statusColor.opacity(0.7)))

                    if !timeLeft.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.7))
                            Text(timeLeft)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.black.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }

                Text(challenge.themeEmoji).font(.system(size: 36))

                Text(challenge.themeName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack {
                    Text(challenge.themeDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)

                    Spacer()

                    actionButton
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onReceive(timer) { _ in updateCountdown() }
        .onAppear { updateCountdown() }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let sub = challenge.mySubmission {
            if sub.status == .confirmed {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                    Text("Entered").font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.2)))
            } else {
                // draft saved, not confirmed
                Button(action: onSubmit) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                        Text("Confirm").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(Color.yellow))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        } else if challenge.status == .collecting {
            Button(action: onSubmit) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                    Text("Submit").font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(Color.white))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var statusLabel: String {
        switch challenge.status {
        case .collecting: return "OPEN"
        case .voting:     return "VOTING"
        case .finals:     return "FINALS"
        case .closed:     return "ENDED"
        case .archived:   return "CLOSED"
        }
    }

    private var statusColor: Color {
        switch challenge.status {
        case .collecting: return .green
        case .voting:     return .orange
        case .finals:     return Color(hex: "#D4AF37")
        case .closed, .archived: return .gray
        }
    }

    private func updateCountdown() {
        let deadline: Date
        switch challenge.status {
        case .collecting: deadline = challenge.collectingEndsAt
        default:          deadline = challenge.finalsEndsAt
        }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { timeLeft = "Closed"; return }
        let d = Int(remaining)
        let days  = d / 86400
        let hours = (d % 86400) / 3600
        let mins  = (d % 3600) / 60
        let secs  = d % 60
        timeLeft = days > 0
            ? String(format: "%dd %02dh %02dm", days, hours, mins)
            : String(format: "%02dh %02dm %02ds", hours, mins, secs)
    }
}

// MARK: - Feed Section

private struct ChallengeFeedSection: View {
    let feed: [ChallengeSubmission]
    let challenge: ChallengeWeek
    let onVote: (ChallengeSubmission) -> Void
    let onLike: (ChallengeSubmission) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if feed.isEmpty {
                ChallengeEmptyFeed(challengeStatus: challenge.status)
            } else {
                Text(challenge.status == .voting ? "VOTE FOR YOUR FAVOURITE" : "THIS WEEK'S ENTRIES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.gazeTextMuted)
                    .tracking(1.5)
                    .padding(.horizontal, 20)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(feed) { sub in
                        ChallengeSubmissionCard(
                            submission: sub,
                            isOwnSubmission: sub.userId == SupabaseManager.shared.currentUserId,
                            onVote: { onVote(sub) },
                            onLike: { onLike(sub) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Submission Card

private struct ChallengeSubmissionCard: View {
    let submission: ChallengeSubmission
    let isOwnSubmission: Bool
    let onVote: () -> Void
    let onLike: () -> Void

    @State private var showDetail = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Image
            AsyncImage(url: URL(string: submission.imageUrl)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    Rectangle().fill(Color.gazeCard)
                        .overlay(Image(systemName: "photo").foregroundStyle(Color.gazeTextMuted))
                default:
                    Rectangle().fill(Color.gazeCard)
                        .overlay(ShimmerView())
                }
            }
            .clipped()

            // Status badge (top-right)
            VStack {
                HStack {
                    Spacer()
                    if isOwnSubmission {
                        Text("👑")
                            .font(.system(size: 16))
                            .padding(6)
                    } else if submission.status == .confirmed {
                        if let end = submission.votingWindowEnd, end > Date() {
                            Text(timeRemaining(until: end))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Capsule().fill(Color.black.opacity(0.5)))
                                .padding(6)
                        }
                    }
                }
                Spacer()
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center, endPoint: .bottom
            )

            // Bottom row
            VStack(spacing: 4) {
                if let uname = submission.username {
                    Text("@\(uname)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                }

                HStack(spacing: 8) {
                    // Vote button
                    if submission.isVotingWindowOpen && !isOwnSubmission {
                        Button(action: onVote) {
                            HStack(spacing: 3) {
                                Image(systemName: submission.hasVoted ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                Text("\(submission.voteCount)")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(submission.hasVoted ? .yellow : .white)
                        }
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.yellow.opacity(0.7))
                            Text("\(submission.voteCount)")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    // Like button
                    Button(action: onLike) {
                        HStack(spacing: 3) {
                            Image(systemName: submission.hasLiked ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                            Text("\(submission.likeCount)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(submission.hasLiked ? .pink : .white)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    submission.hasVoted ? Color(hex: "#D4AF37").opacity(0.8) : Color.gazeBorder.opacity(0.5),
                    lineWidth: submission.hasVoted ? 2 : 0.5
                )
        )
        .aspectRatio(3/4, contentMode: .fit)
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            SubmissionDetailSheet(submission: submission, isOwnSubmission: isOwnSubmission)
        }
    }

    private func timeRemaining(until date: Date) -> String {
        let s = max(0, date.timeIntervalSinceNow)
        let h = Int(s / 3600)
        let m = Int((s.truncatingRemainder(dividingBy: 3600)) / 60)
        return h > 0 ? "\(h)h left" : "\(m)m left"
    }
}

// MARK: - Submission Detail Sheet

private struct SubmissionDetailSheet: View {
    let submission: ChallengeSubmission
    let isOwnSubmission: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Full photo
                    AsyncImage(url: URL(string: submission.imageUrl),
                               transaction: Transaction(animation: .easeIn(duration: 0.22))) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .transition(.opacity)
                        default:
                            Rectangle().fill(Color.white.opacity(0.05))
                                .aspectRatio(3/4, contentMode: .fit)
                                .overlay(ShimmerView())
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Stats row
                    HStack(spacing: 0) {
                        // Votes
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.yellow)
                                Text("\(submission.voteCount)")
                                    .font(.system(size: 36, weight: .black))
                                    .foregroundStyle(.white)
                            }
                            Text(isOwnSubmission ? "Your Votes" : "Votes")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1, height: 50)

                        // Likes
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.pink)
                                Text("\(submission.likeCount)")
                                    .font(.system(size: 36, weight: .black))
                                    .foregroundStyle(.white)
                            }
                            Text("Likes")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 28)

                    if isOwnSubmission {
                        Text("👑  Your Entry")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.bottom, 32)
                    }
                }
            }

            // Close button
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .presentationBackground(Color.black)
    }
}

// MARK: - Finals Section

private struct ChallengeFinalsSection: View {
    let finalists: [ChallengeSubmission]
    let challenge: ChallengeWeek
    let onVote: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Finals")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.gazeTextPrimary)
                    .padding(.horizontal)
                Text("Vote for your favourite look. One vote total.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if challenge.myFinalsVoteId != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Vote cast")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.gazeTextSecondary)
                }
                .padding(.horizontal)
            }

            if finalists.isEmpty {
                ChallengeEmptyFeed(challengeStatus: .finals)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(finalists) { sub in
                        ChallengeFinalistCard(
                            submission: sub,
                            hasGlobalVote: challenge.myFinalsVoteId != nil,
                            onVote: { onVote(sub.id) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct ChallengeFinalistCard: View {
    let submission: ChallengeSubmission
    let hasGlobalVote: Bool
    let onVote: () -> Void

    var isMyVote: Bool { submission.userHasVotedFinals == true }

    var body: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: URL(string: submission.imageUrl)) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Rectangle().fill(Color.gazeCard)
                }
            }
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center, endPoint: .bottom
            )

            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                    Text("\(submission.finalsVoteCount ?? 0)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }

                if isMyVote {
                    Label("Your vote", systemImage: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.yellow)
                } else if !hasGlobalVote {
                    Button(action: onVote) {
                        Text("Vote")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(Capsule().fill(Color.white))
                    }
                }
            }
            .padding(.bottom, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isMyVote ? Color.yellow : Color.clear, lineWidth: 2)
        )
        .aspectRatio(3/4, contentMode: .fit)
    }
}

// MARK: - Empty Feed

private struct ChallengeEmptyFeed: View {
    let challengeStatus: ChallengeStatus

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.gazeTextMuted)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Color.gazeTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var icon: String {
        switch challengeStatus {
        case .collecting: return "camera"
        case .voting:     return "star"
        case .finals:     return "crown"
        case .closed, .archived: return "trophy"
        }
    }

    private var message: String {
        switch challengeStatus {
        case .collecting: return "Be the first to submit this week."
        case .voting:     return "No submissions in the voting window yet."
        case .finals:     return "Finals starting soon — check back."
        case .closed, .archived: return "This challenge has ended."
        }
    }
}

// MARK: - Skeleton

private struct ChallengeSkeletonView: View {
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 16) {
            ShimmerView()
                .frame(maxWidth: .infinity).frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(0..<6, id: \.self) { _ in
                    ShimmerView()
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Submit Sheet

struct ChallengeSubmitSheet: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: ChallengeViewModel
    @EnvironmentObject private var appVM: AppViewModel

    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showCaptionEntry = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gazeBackground.ignoresSafeArea()

                if vm.showConfirmLockWarning {
                    // Step 3: Lock warning
                    ChallengeConfirmSheet()
                        .environmentObject(vm)
                } else if vm.pendingImage != nil {
                    // Step 2: Caption
                    ChallengeCaptionEntry(
                        image: vm.pendingImage!,
                        caption: $vm.pendingCaption,
                        isLoading: vm.isDraftSaving,
                        onSubmit: {
                            Task { await vm.saveDraft() }
                        },
                        onBack: {
                            vm.pendingImage = nil
                            vm.pendingCaption = ""
                        }
                    )
                } else {
                    // Step 1: Pick photo
                    ChallengePhotoPickerStep(
                        showCamera: $showCamera,
                        selectedItem: $selectedItem
                    )
                    .environmentObject(vm)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { vm.cancelDraft(); dismiss() }
                        .foregroundStyle(Color.gazeTextSecondary)
                }
            }
            .preferredColorScheme(.light)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                vm.pendingImage = image
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    vm.pendingImage = image
                }
            }
        }
    }
}

// Step 1
private struct ChallengePhotoPickerStep: View {
    @Binding var showCamera: Bool
    @Binding var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 10) {
            Button { showCamera = true } label: {
                submitOptionRow(icon: "camera.fill", label: "Take a Photo")
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                submitOptionRow(icon: "photo.on.rectangle.angled", label: "Choose from Library")
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .navigationTitle("Submit Your Fit")
    }

    private func submitOptionRow(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.gazeTextPrimary)
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.gazeTextPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.gazeTextMuted)
        }
        .padding(14)
        .background(Color.gazeCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.gazeBorder, lineWidth: 1))
    }
}

// Step 2
private struct ChallengeCaptionEntry: View {
    let image: UIImage
    @Binding var caption: String
    let isLoading: Bool
    let onSubmit: () -> Void
    let onBack: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Caption (optional)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.gazeTextMuted)

                    TextField("Describe your fit…", text: $caption)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gazeTextPrimary)
                        .focused($focused)
                        .padding(14)
                        .background(Color.gazeCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)

                if isLoading {
                    ProgressView("Uploading…").tint(Color.gazeAccent)
                } else {
                    GazeButton(label: "Continue", icon: "arrow.right", style: .primary) {
                        onSubmit()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
        }
        .navigationTitle("Add Caption")
        .onAppear { focused = true }
    }
}

// Step 3 — Lock warning
private struct ChallengeConfirmSheet: View {
    @EnvironmentObject private var vm: ChallengeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("🔒")
                    .font(.system(size: 48))
                Text("Lock in your submission?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.gazeTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Once confirmed, your entry is locked for the week. You can't swap or edit it.\nVoting opens immediately for 24 hours.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.gazeTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            if let sub = vm.challenge?.mySubmission {
                AsyncImage(url: URL(string: sub.imageUrl)) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFit()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                if vm.isConfirming {
                    ProgressView("Confirming…").tint(Color.gazeAccent)
                } else {
                    GazeButton(label: "Yes, lock it in", icon: "lock.fill", style: .primary) {
                        Task { await vm.confirmSubmission() }
                    }
                    .padding(.horizontal, 24)

                    Button("Go back") {
                        vm.showConfirmLockWarning = false
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Color.gazeTextSecondary)
                }
            }

            Spacer()
        }
        .navigationTitle("Confirm Entry")
    }
}

// MARK: - Challenge Info Sheet

struct ChallengeInfoSheet: View {
    let challenge: ChallengeWeek
    let onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: challenge.themeGradientStart),
                Color(hex: challenge.themeGradientEnd)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            Color.gazeBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(gradient).frame(height: 180)
                        Circle().fill(Color.white.opacity(0.06))
                            .frame(width: 200, height: 200).offset(x: 200, y: -40)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(challenge.themeEmoji).font(.system(size: 40))
                            Text(challenge.themeName)
                                .font(.system(size: 24, weight: .black)).foregroundStyle(.white)
                            Text("Week \(challenge.isoWeek)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7)).tracking(1.5)
                        }
                        .padding(20)
                    }
                    .background(gradient.ignoresSafeArea(edges: .top))

                    VStack(alignment: .leading, spacing: 28) {
                        // How it works
                        VStack(alignment: .leading, spacing: 14) {
                            Text("HOW IT WORKS")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color.gazeTextMuted).tracking(2)

                            VStack(alignment: .leading, spacing: 12) {
                                InfoRow(number: "1", text: "Submit a photo that matches this week's theme (Mon–Fri).")
                                InfoRow(number: "2", text: "Each submission gets a 24-hour voting window immediately.")
                                InfoRow(number: "3", text: "Top 3 entries per day advance to Sunday finals.")
                                InfoRow(number: "4", text: "The finalist with the most finals votes wins the $100 prize.")
                            }
                        }

                        // Prize callout
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color(hex: "#D4AF37").opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Text("🏆").font(.system(size: 22))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("$100 Gift Voucher")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color(hex: "#D4AF37"))
                                Text("Winner picks any shop they want.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.gazeTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(hex: "#D4AF37").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color(hex: "#D4AF37").opacity(0.2), lineWidth: 1)
                        )

                        // Theme description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("THIS WEEK'S THEME")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color.gazeTextMuted).tracking(2)
                            Text(challenge.themeDescription)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.gazeTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if challenge.status == .collecting && challenge.mySubmission == nil {
                            GazeButton(label: "Submit Your Look", icon: "plus", style: .primary) {
                                onSubmit()
                            }
                        } else if challenge.mySubmission?.status == .confirmed {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.gazeSuccess)
                                Text("You've entered this week!")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.gazeTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.gazeCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(20)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                ZStack {
                    Circle().fill(Color.black.opacity(0.4)).frame(width: 30, height: 30)
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                }
            }
            .padding(.top, 16).padding(.trailing, 16)
        }
        .presentationDetents([.large])
        .preferredColorScheme(.light)
    }
}

private struct InfoRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.gazeCard).frame(width: 24, height: 24)
                Text(number).font(.system(size: 11, weight: .bold)).foregroundStyle(Color.gazeTextSecondary)
            }
            Text(text)
                .font(.system(size: 14)).foregroundStyle(Color.gazeTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: - Legacy types (kept for backward-compat with ProfileView's Runway section)

struct WeeklyChallenge {
    let weekNumber: Int
    let year: Int
    let theme: ChallengeTheme
    let endsAt: Date

    static var current: WeeklyChallenge {
        let iso = Calendar(identifier: .iso8601)
        let greg = Calendar.current
        let now = Date()
        let week = iso.component(.weekOfYear, from: now)
        let year = iso.component(.yearForWeekOfYear, from: now)
        let wd = greg.component(.weekday, from: now)
        let daysUntilSunday = wd == 1 ? 0 : 7 - (wd - 1)
        let sunday = greg.startOfDay(for: greg.date(byAdding: .day, value: daysUntilSunday, to: now)!)
        let endsAt = greg.date(bySettingHour: 18, minute: 0, second: 0, of: sunday)!
        let theme = ChallengeTheme.allThemes[(week - 1) % ChallengeTheme.allThemes.count]
        return WeeklyChallenge(weekNumber: week, year: year, theme: theme, endsAt: endsAt)
    }
}

struct ChallengeTheme {
    let name: String
    let emoji: String
    let description: String
    let gradientStart: String
    let gradientEnd: String

    static let allThemes: [ChallengeTheme] = [
        ChallengeTheme(name: "All Black", emoji: "🖤", description: "Head to toe black. Make it look effortless.", gradientStart: "#1a1a1a", gradientEnd: "#3d3d3d"),
        ChallengeTheme(name: "Old Money", emoji: "🎩", description: "Polo, loafers, blazer. Wealth you never talk about.", gradientStart: "#2c3e50", gradientEnd: "#bdc3c7"),
        ChallengeTheme(name: "Streetwear", emoji: "👟", description: "Clean kicks, fresh graphics, urban energy.", gradientStart: "#1a1a2e", gradientEnd: "#16213e"),
        ChallengeTheme(name: "Summer Fit", emoji: "☀️", description: "Light fabrics, bright colours, warm energy.", gradientStart: "#f7971e", gradientEnd: "#ffd200"),
        ChallengeTheme(name: "All White", emoji: "🤍", description: "Pure white head to toe. Keep it spotless.", gradientStart: "#d9d9d9", gradientEnd: "#f5f5f5"),
        ChallengeTheme(name: "Quiet Luxury", emoji: "✨", description: "No logos. Just quality, fit, and taste.", gradientStart: "#c9b99a", gradientEnd: "#8b7355"),
        ChallengeTheme(name: "Night Out", emoji: "🌙", description: "You're going out. Dress like it.", gradientStart: "#141e30", gradientEnd: "#243b55"),
        ChallengeTheme(name: "Casual Friday", emoji: "😎", description: "Relaxed but put together. Friday done right.", gradientStart: "#4e54c8", gradientEnd: "#8f94fb"),
        ChallengeTheme(name: "Monochrome", emoji: "⚫", description: "One colour, head to toe. Own it.", gradientStart: "#4b4b4b", gradientEnd: "#8e8e8e"),
        ChallengeTheme(name: "Denim on Denim", emoji: "👖", description: "Double denim, no apologies.", gradientStart: "#1e4d8c", gradientEnd: "#4a90d9"),
        ChallengeTheme(name: "Athleisure", emoji: "⚡", description: "Sporty but make it fashion.", gradientStart: "#00c9ff", gradientEnd: "#92fe9d"),
        ChallengeTheme(name: "Business Casual", emoji: "💼", description: "Office-ready but make it cool.", gradientStart: "#485563", gradientEnd: "#29323c"),
        ChallengeTheme(name: "Oversized", emoji: "🗿", description: "Big silhouettes, effortless drape.", gradientStart: "#636363", gradientEnd: "#a2ab58"),
        ChallengeTheme(name: "Date Night", emoji: "❤️", description: "You're trying to impress. Show us the fit.", gradientStart: "#c94b4b", gradientEnd: "#4b134f"),
        ChallengeTheme(name: "Vacation Mode", emoji: "✈️", description: "Resort wear, linen, holiday energy.", gradientStart: "#2980b9", gradientEnd: "#6dd5fa"),
        ChallengeTheme(name: "Minimalist", emoji: "◻️", description: "Less is more. Clean, simple, sharp.", gradientStart: "#e0e0e0", gradientEnd: "#bdbdbd"),
        ChallengeTheme(name: "Designer Flex", emoji: "💎", description: "Show the labels. Logos out.", gradientStart: "#1a1a2e", gradientEnd: "#6b4f2e"),
        ChallengeTheme(name: "Vintage", emoji: "🕰️", description: "Thrifted, retro, timeless. Old is gold.", gradientStart: "#c79081", gradientEnd: "#dfa579"),
        ChallengeTheme(name: "Y2K", emoji: "💿", description: "Early 2000s energy. Low rise, butterfly clips, chaos.", gradientStart: "#a18cd1", gradientEnd: "#fbc2eb"),
        ChallengeTheme(name: "Smart Casual", emoji: "🧥", description: "Elevated basics. Neat without being formal.", gradientStart: "#373b44", gradientEnd: "#8e9eab"),
        ChallengeTheme(name: "Colour Pop", emoji: "🌈", description: "One bold colour. Make it the focal point.", gradientStart: "#fc5c7d", gradientEnd: "#6a82fb"),
        ChallengeTheme(name: "Leather Fit", emoji: "🖤🧥", description: "Leather jacket, leather pants, leather everything.", gradientStart: "#1a1a1a", gradientEnd: "#4a3728"),
        ChallengeTheme(name: "Sporty", emoji: "🏀", description: "Athletic wear done with intention.", gradientStart: "#0099f7", gradientEnd: "#f11712"),
        ChallengeTheme(name: "Earth Tones", emoji: "🌍", description: "Terracotta, olive, sand, brown. Nature's colours.", gradientStart: "#a0522d", gradientEnd: "#deb887"),
        ChallengeTheme(name: "Weekend Fit", emoji: "🛋️", description: "Comfy but still stylish. Saturday morning energy.", gradientStart: "#8e9eab", gradientEnd: "#eef2f3"),
        ChallengeTheme(name: "Formal", emoji: "🎭", description: "Full suit. Dress like the main character.", gradientStart: "#1f1c2c", gradientEnd: "#928dab"),
        ChallengeTheme(name: "Puffer Season", emoji: "🧊", description: "Oversized puffers, winter drip.", gradientStart: "#3a7bd5", gradientEnd: "#3a6073"),
        ChallengeTheme(name: "Layered Look", emoji: "🧅", description: "Stack it up. Textures, lengths, dimensions.", gradientStart: "#4e4376", gradientEnd: "#2b5876"),
        ChallengeTheme(name: "Festival", emoji: "🎪", description: "Go all out. No rules at the festival.", gradientStart: "#f953c6", gradientEnd: "#b91d73"),
        ChallengeTheme(name: "Beach Fit", emoji: "🏖️", description: "Shorts, slides, coastal energy. Keep it breezy.", gradientStart: "#56ccf2", gradientEnd: "#2f80ed"),
        ChallengeTheme(name: "Preppy", emoji: "⛵", description: "Polos, cable knits, clean-cut and classic.", gradientStart: "#2e86ab", gradientEnd: "#a23b72"),
        ChallengeTheme(name: "Neutral Tones", emoji: "🏜️", description: "Beige, cream, grey, taupe. Tone it down.", gradientStart: "#d4c5a9", gradientEnd: "#9d8b7a"),
        ChallengeTheme(name: "Techwear", emoji: "🤖", description: "Functional meets futuristic. Utility pockets included.", gradientStart: "#0f0c29", gradientEnd: "#302b63"),
        ChallengeTheme(name: "Floral", emoji: "🌸", description: "Florals. Done properly.", gradientStart: "#f7797d", gradientEnd: "#fbd3e9"),
        ChallengeTheme(name: "Power Suit", emoji: "💪", description: "Dressed for business. Full suit, no compromise.", gradientStart: "#232526", gradientEnd: "#414345"),
        ChallengeTheme(name: "Trench Coat Fit", emoji: "🧥", description: "The trench coat is the outfit. Build around it.", gradientStart: "#c8a96e", gradientEnd: "#8b6914"),
        ChallengeTheme(name: "Classic Denim", emoji: "🔵", description: "Jeans and a tee done perfectly.", gradientStart: "#1e4d8c", gradientEnd: "#6dd5fa"),
        ChallengeTheme(name: "Retro Vibes", emoji: "🕺", description: "70s flares, 80s jackets, 90s hoodies. Pick your decade.", gradientStart: "#c97e3a", gradientEnd: "#7b5c2a"),
        ChallengeTheme(name: "Sneaker Fit", emoji: "👟", description: "The sneakers are the centrepiece. Build the fit around them.", gradientStart: "#ff6a00", gradientEnd: "#ee0979"),
        ChallengeTheme(name: "Cozy Fit", emoji: "🍂", description: "Knits, scarves, warm tones. Autumn mode.", gradientStart: "#d4882a", gradientEnd: "#8b4513"),
        ChallengeTheme(name: "Boho", emoji: "🪶", description: "Flowy fabrics, earthy accessories, free spirit.", gradientStart: "#d4a054", gradientEnd: "#8e5c2e"),
        ChallengeTheme(name: "Tropical", emoji: "🌴", description: "Prints, colour, island energy.", gradientStart: "#11998e", gradientEnd: "#38ef7d"),
        ChallengeTheme(name: "Tonal Outfit", emoji: "🎨", description: "Same colour family, different shades. Tone on tone.", gradientStart: "#7f7fd5", gradientEnd: "#86a8e7"),
        ChallengeTheme(name: "Colour Block", emoji: "🟥🟦", description: "Bold blocks of colour. Clean and graphic.", gradientStart: "#1a6dff", gradientEnd: "#c822ff"),
        ChallengeTheme(name: "Utility Look", emoji: "🔧", description: "Cargo, boots, tactical. Workwear as fashion.", gradientStart: "#4a4a4a", gradientEnd: "#7a6a50"),
        ChallengeTheme(name: "Varsity", emoji: "🏆", description: "Varsity jacket, clean kicks, sporty classic.", gradientStart: "#c0392b", gradientEnd: "#8e44ad"),
        ChallengeTheme(name: "Black Tie", emoji: "🎩", description: "Full black tie. Tux, gown, or a creative take.", gradientStart: "#0d0d0d", gradientEnd: "#2c2c2c"),
        ChallengeTheme(name: "Street Style", emoji: "📸", description: "Dress like the cameras are on you.", gradientStart: "#373737", gradientEnd: "#717171"),
        ChallengeTheme(name: "Printed Fits", emoji: "🖨️", description: "Bold prints, loud patterns. No blank canvases.", gradientStart: "#f7971e", gradientEnd: "#b91d73"),
        ChallengeTheme(name: "Smart Layers", emoji: "🧤", description: "Blazer over hoodie. Coat over suit. Make it work.", gradientStart: "#2c3e50", gradientEnd: "#4ca1af"),
        ChallengeTheme(name: "Summer Linen", emoji: "🌾", description: "Linen everything. Relaxed, airy, effortless.", gradientStart: "#e8d5b7", gradientEnd: "#c4a882"),
        ChallengeTheme(name: "Monogram & Logos", emoji: "🏷️", description: "Let the branding speak. Logos front and centre.", gradientStart: "#D4AF37", gradientEnd: "#8B6914"),
    ]
}
