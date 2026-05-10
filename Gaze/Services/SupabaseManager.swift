import Foundation
import Supabase

// MARK: - Supabase Client Singleton

final class SupabaseManager {

    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        guard let configURL = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
              let config = NSDictionary(contentsOf: configURL),
              let urlString = config["SUPABASE_URL"] as? String,
              let anonKey = config["SUPABASE_ANON_KEY"] as? String,
              let supabaseURL = URL(string: urlString) else {
            fatalError("SupabaseConfig.plist missing or invalid — add SUPABASE_URL and SUPABASE_ANON_KEY")
        }
        // Opt in to emitting the locally stored session immediately (avoids SDK `reportIssue` noise
        // and matches the next major release). Callers must treat expired sessions explicitly — see
        // `SupabaseService.sessionForAppRouting()`.
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
        AppLogger.info("Supabase client initialized", category: .auth)
    }

    var currentUserId: UUID? {
        client.auth.currentSession?.user.id
    }
}
