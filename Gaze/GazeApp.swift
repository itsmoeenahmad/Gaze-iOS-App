import SwiftUI
import UIKit
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct GAZEApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var appViewModel = AppViewModel()

    init() {
        // 64 MB RAM + 512 MB disk cache so AsyncImage never re-downloads the same photo
        URLCache.shared = URLCache(
            memoryCapacity: 64  * 1024 * 1024,
            diskCapacity:   512 * 1024 * 1024,
            diskPath: "gaze_image_cache"
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appViewModel)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Root Router

struct RootView: View {

    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        ZStack {
            Color.gazeBackground.ignoresSafeArea()

            switch appVM.appState {

            case .loading:
                LoadingSplashView()
                    .transition(.opacity)

            case .auth:
                AuthView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .setupProfile(let userId):
                UsernameSetupView(userId: userId)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))

            case .main:
                ContentView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(GazeAnimations.spring, value: stateId)
    }

    private var stateId: Int {
        switch appVM.appState {
        case .loading:       return 0
        case .auth:          return 1
        case .setupProfile:  return 2
        case .main:          return 3
        }
    }
}

// MARK: - Loading Splash

private struct LoadingSplashView: View {
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()
            Text("GAZE")
                .font(.system(size: 52, weight: .black))
                .foregroundStyle(.white)
                .kerning(10)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { opacity = 1 }
        }
    }
}
