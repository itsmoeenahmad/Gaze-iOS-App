import SwiftUI

// MARK: - Root Content View

struct ContentView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @StateObject private var postVM = PostViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.gazeBackground.ignoresSafeArea()

            // Tab views — kept alive after first visit
            ZStack {
                NavigationStack {
                    HomeFeedView()
                        .navigationDestination(for: GazeUser.self) { user in UserProfileView(user: user) }
                        .navigationDestination(for: Outfit.self) { outfit in OutfitDetailView(outfit: outfit) }
                }
                .opacity(appVM.selectedTab == .feed ? 1 : 0)
                .allowsHitTesting(appVM.selectedTab == .feed)

                NavigationStack {
                    ExploreView()
                        .navigationDestination(for: GazeUser.self) { user in UserProfileView(user: user) }
                        .navigationDestination(for: Outfit.self) { outfit in OutfitDetailView(outfit: outfit) }
                }
                .opacity(appVM.selectedTab == .explore ? 1 : 0)
                .allowsHitTesting(appVM.selectedTab == .explore)

                NavigationStack {
                    ChallengeView()
                        .navigationDestination(for: GazeUser.self) { user in UserProfileView(user: user) }
                        .navigationDestination(for: Outfit.self) { outfit in OutfitDetailView(outfit: outfit) }
                }
                .opacity(appVM.selectedTab == .trending ? 1 : 0)
                .allowsHitTesting(appVM.selectedTab == .trending)

                NavigationStack {
                    ProfileView()
                        .navigationDestination(for: GazeUser.self) { user in UserProfileView(user: user) }
                        .navigationDestination(for: Outfit.self) { outfit in OutfitDetailView(outfit: outfit) }
                }
                .opacity(appVM.selectedTab == .profile ? 1 : 0)
                .allowsHitTesting(appVM.selectedTab == .profile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.18), value: appVM.selectedTab)

            // Tab bar
            GazeTabBar(selectedTab: $appVM.selectedTab) {
                appVM.showPostSheet = true
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $appVM.showPostSheet) {
            PostView(vm: postVM)
                .environmentObject(appVM)
        }
        .sheet(isPresented: $appVM.showNotifications) {
            NotificationsView()
        }
    }
}
