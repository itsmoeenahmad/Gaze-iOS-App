import SwiftUI

// MARK: - Ranking View

struct RankingView: View {

    @StateObject private var vm = RankingViewModel()
    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        ZStack(alignment: .top) {
            Color.gazeBackground.ignoresSafeArea()

            if vm.isLoading {
                VStack {
                    Spacer().frame(height: 130)
                    RankingLoadingView()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 130)

                        VStack(spacing: 0) {
                            ForEach(Array(vm.currentRankings.enumerated()), id: \.element.id) { idx, entry in
                                LeaderboardRow(entry: entry, position: idx + 1)
                                    .opacity(vm.animateEntries ? 1.0 : 0.0)
                                    .offset(y: vm.animateEntries ? 0 : 16)
                                    .animation(
                                        GazeAnimations.spring.delay(Double(idx) * 0.035),
                                        value: vm.animateEntries
                                    )

                                if idx < vm.currentRankings.count - 1 {
                                    Divider()
                                        .background(Color.gazeBorder)
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color.gazeCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.gazeBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 100)
                    }
                }
                .refreshable { vm.refresh() }
            }

            // Sticky header
            RankingHeader(
                selectedScope: vm.selectedScope,
                onSelect: vm.selectScope
            )
        }
        .onAppear {
            if vm.rankings.isEmpty {
                let city = appVM.currentUser.city.isEmpty ? nil : appVM.currentUser.city
                vm.load(city: city)
            }
        }
    }
}

// MARK: - Header

private struct RankingHeader: View {
    let selectedScope: RankingScope
    let onSelect: (RankingScope) -> Void

    var body: some View {
        VStack(spacing: 14) {
            titleRow
            scopeSwitcher
        }
        .padding(.top, 56)
        .padding(.bottom, 14)
        .background(Color.gazeBackground)
    }

    private var titleRow: some View {
        HStack {
            Text("Rankings")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.gazeTextPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var scopeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(RankingScope.allCases, id: \.self) { scope in
                RankingScopeChip(
                    title: scope.rawValue,
                    isSelected: selectedScope == scope
                ) {
                    GazeHaptics.selection()
                    withAnimation(GazeAnimations.springSnappy) {
                        onSelect(scope)
                    }
                }
                .animation(GazeAnimations.springSnappy, value: selectedScope)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gazeCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.gazeBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

/// Extracted so the main header `body` type-checks quickly (SwiftUI overload resolution).
private struct RankingScopeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black : Color.gazeTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(chipBackground)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var chipBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.gazeAccent)
        }
    }
}

// MARK: - Leaderboard Row

private struct LeaderboardRow: View {
    let entry: RankingEntry
    let position: Int

    private var podiumColor: Color? {
        switch position {
        case 1: return Color(hex: "#FFFFFF")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: GazeGradients.gradient(for: entry.user.gradientIndex),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Text(String(entry.user.displayName.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
            }
            .overlay(
                Circle()
                    .strokeBorder(
                        podiumColor.map { $0.opacity(0.6) } ?? Color.gazeBorder,
                        lineWidth: podiumColor != nil ? 1.5 : 1
                    )
            )

            // Username + city
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("@\(entry.user.username)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.gazeTextPrimary)
                        .lineLimit(1)
                    if position <= 3, let color = podiumColor {
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                }
                Text(entry.user.city)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gazeTextSecondary)
            }

            Spacer()

            // Score
            Text(String(format: "%.1f", entry.score))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(podiumColor ?? Color.gazeTextSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Loading

private struct RankingLoadingView: View {
    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<8, id: \.self) { _ in
                ShimmerView()
                    .frame(height: 72)
                    .padding(.horizontal, 16)
            }
        }
    }
}
