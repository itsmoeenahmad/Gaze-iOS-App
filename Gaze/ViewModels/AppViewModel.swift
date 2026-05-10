import SwiftUI
import Combine
import Auth
import Foundation

// MARK: - App State

enum GazeAppState {
    case loading
    case auth
    case setupProfile(userId: UUID)
    case main
}

// MARK: - App ViewModel (Global State)

@MainActor
final class AppViewModel: ObservableObject {

    @Published var appState: GazeAppState = .loading
    @Published var selectedTab: GazeTab = .feed
    @Published var currentUser: GazeUser = MockDataService.shared.currentUser

    @Published var showPostSheet     = false
    @Published var showNotifications = false
    @Published var notificationCount = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        Task { await checkSession() }
        NotificationCenter.default.publisher(for: .gazeFollowingCountChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, let delta = notification.object as? Int else { return }
                self.currentUser.followingCount = max(0, self.currentUser.followingCount + delta)
            }
            .store(in: &cancellables)
    }

    // MARK: - Session check on launch

    func checkSession() async {
        AppLogger.info("Checking existing session", category: .auth)
        guard let session = await SupabaseService.shared.sessionForAppRouting() else {
            AppLogger.info("No active session, showing auth", category: .auth)
            withAnimation(GazeAnimations.standard) { appState = .auth }
            return
        }
        do {
            let profile = try await SupabaseService.shared.fetchProfile(id: session.user.id)
            currentUser = profile.toGazeUser()
            AppLogger.info("Session restored", category: .auth, properties: ["user_id": session.user.id.uuidString])
            withAnimation(GazeAnimations.standard) { appState = .main }
            await refreshNotificationCount()
            await SupabaseService.shared.refreshBlockedCache(userId: session.user.id)
        } catch {
            AppLogger.warning("Session exists but profile missing, routing to setup", category: .auth, properties: ["user_id": session.user.id.uuidString, "error": error.localizedDescription])
            withAnimation(GazeAnimations.standard) {
                appState = .setupProfile(userId: session.user.id)
            }
        }
    }

    // MARK: - Auth callbacks

    func onSignedUp(userId: UUID) async {
        AppLogger.info("Sign-up completed, routing to profile setup", category: .auth, properties: ["user_id": userId.uuidString])
        withAnimation(GazeAnimations.standard) {
            appState = .setupProfile(userId: userId)
        }
    }

    func onSignedIn() async {
        guard let session = SupabaseService.shared.currentSession() else {
            AppLogger.warning("onSignedIn called but no session found", category: .auth)
            return
        }
        AppLogger.info("Sign-in completed, loading profile", category: .auth, properties: ["user_id": session.user.id.uuidString])
        do {
            let profile = try await SupabaseService.shared.fetchProfile(id: session.user.id)
            currentUser = profile.toGazeUser()
            withAnimation(GazeAnimations.standard) { appState = .main }
            await refreshNotificationCount()
            await SupabaseService.shared.refreshBlockedCache(userId: session.user.id)
        } catch {
            AppLogger.warning("Profile not found after sign-in, routing to setup", category: .auth, properties: ["error": error.localizedDescription])
            withAnimation(GazeAnimations.standard) {
                appState = .setupProfile(userId: session.user.id)
            }
        }
    }

    func refreshNotificationCount() async {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        let notifications = (try? await SupabaseService.shared.fetchNotifications(userId: userId)) ?? []
        notificationCount = notifications.filter { !$0.isRead }.count
        AppLogger.debug("Notification count refreshed", category: .social, properties: ["unread": "\(notificationCount)"])
    }

    func onProfileCreated(userId: UUID, username: String, displayName: String,
                          city: String, category: StyleCategory) async {
        AppLogger.info("Profile created, entering main app", category: .auth, properties: ["user_id": userId.uuidString])
        currentUser = GazeUser(
            id: userId,
            username: username,
            displayName: displayName,
            avatarColorHex: "#2d1b69",
            city: city,
            bio: "",
            styleScore: 0,
            styleCategory: category,
            followerCount: 0,
            followingCount: 0,
            outfitCount: 0,
            isVerified: false,
            isFollowing: false,
            gradientIndex: abs(userId.hashValue) % 20
        )
        withAnimation(GazeAnimations.standard) { appState = .main }
    }

    func signOut() async {
        AppLogger.info("Sign-out initiated", category: .auth)
        do {
            try await SupabaseService.shared.signOut()
            AppLogger.info("Sign-out completed", category: .auth)
        } catch {
            AppLogger.warning("Sign-out backend call failed, clearing local session anyway", category: .auth, properties: ["error": error.localizedDescription])
        }
        SupabaseService.shared.clearBlockedUserIdsCache()
        notificationCount = 0
        withAnimation(GazeAnimations.standard) { appState = .auth }
    }

    // MARK: - Navigation

    func switchTab(_ tab: GazeTab) {
        GazeHaptics.selection()
        withAnimation(GazeAnimations.springSnappy) { selectedTab = tab }
    }
}
