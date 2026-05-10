import SwiftUI
import Combine

// MARK: - Ranking ViewModel

@MainActor
final class RankingViewModel: ObservableObject {

    @Published var selectedScope: RankingScope = .city
    @Published var rankings: [RankingScope: [RankingEntry]] = [:]
    @Published var isLoading = true
    @Published var selectedUser: GazeUser? = nil
    @Published var animateEntries = false

    private var userCity: String? = nil

    var currentRankings: [RankingEntry] {
        rankings[selectedScope] ?? []
    }

    func load(city: String? = nil) {
        userCity = city
        isLoading = true
        Task {
            do {
                async let cityRankings   = SupabaseService.shared.fetchRankings(scope: .city,   city: city)
                async let globalRankings = SupabaseService.shared.fetchRankings(scope: .global, city: nil)
                let (cityResult, globalResult) = try await (cityRankings, globalRankings)
                rankings[.city]   = cityResult
                rankings[.global] = globalResult
            } catch {
                rankings[.city]   = []
                rankings[.global] = []
            }
            isLoading = false
            withAnimation(GazeAnimations.spring.delay(0.1)) {
                animateEntries = true
            }
        }
    }

    func selectScope(_ scope: RankingScope) {
        GazeHaptics.selection()
        animateEntries = false
        withAnimation(GazeAnimations.springSnappy) {
            selectedScope = scope
        }
        withAnimation(GazeAnimations.spring.delay(0.05)) {
            animateEntries = true
        }
    }

    func refresh() {
        animateEntries = false
        rankings = [:]
        load(city: userCity)
    }
}
