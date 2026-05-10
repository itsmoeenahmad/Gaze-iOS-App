import SwiftUI

// MARK: - Explore View

struct ExploreView: View {

    @StateObject private var vm = ExploreViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            Color.gazeBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if vm.isLoading {
                        ExploreLoadingSkeleton()
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    } else if vm.filteredOutfits.isEmpty {
                        ExploreEmptyState()
                            .padding(.top, 80)
                    } else {
                        ExploreGrid(outfits: vm.filteredOutfits, onLastItemAppear: {
                            vm.loadMore()
                        })
                        if vm.isLoadingMore {
                            ProgressView()
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Spacer().frame(height: 100)
                }
            }
            .refreshable { await vm.loadAsync() }
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 106) }

            // Header — title + search
            ExploreHeader(searchText: $vm.searchText, isAISearching: vm.isAISearching)
        }
        .onAppear {
            if vm.allOutfits.isEmpty { vm.load() }
        }
    }
}

// MARK: - Header

private struct ExploreHeader: View {
    @Binding var searchText: String
    var isAISearching: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                Text("Explore")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.gazeTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            HStack(spacing: 10) {
                if isAISearching {
                    ProgressView()
                        .scaleEffect(0.75)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.gazeTextMuted)
                }

                TextField("", text: $searchText,
                          prompt: Text("Search styles, brands…")
                              .foregroundStyle(Color.gazeTextMuted))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.gazeTextPrimary)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        focused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.gazeTextMuted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.gazeCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        focused ? Color.gazeAccent.opacity(0.5) : Color.gazeBorder,
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)
            .animation(GazeAnimations.fast, value: focused)
        }
        .padding(.bottom, 10)
        .background(Color.gazeBackground.opacity(0.97).ignoresSafeArea(edges: .top))
    }
}

// MARK: - Grid

private struct ExploreGrid: View {
    let outfits: [Outfit]
    var onLastItemAppear: (() -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(outfits) { outfit in
                ExploreGridCell(outfit: outfit)
                    .onAppear {
                        if outfit.id == outfits.last?.id {
                            onLastItemAppear?()
                        }
                    }
            }
        }
    }
}

// MARK: - Grid Cell

private struct ExploreGridCell: View {
    let outfit: Outfit

    @State private var appeared = false

    var body: some View {
        NavigationLink(value: outfit) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    OutfitCard(outfit: outfit, cornerRadius: 0)
                }
                .clipped()
        }
        .buttonStyle(GazePressStyle(scale: 0.97))
        .opacity(appeared ? 1 : 0)
        .animation(.easeIn(duration: 0.18).delay(Double(abs(outfit.id.hashValue) % 10) * 0.012), value: appeared)
        .onAppear { appeared = true }
    }
}

// MARK: - Empty State

private struct ExploreEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Color.gazeTextMuted)
            Text("No outfits found")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.gazeTextSecondary)
            Text("Try a different search term")
                .font(.system(size: 13))
                .foregroundStyle(Color.gazeTextMuted)
        }
    }
}

// MARK: - Loading Skeleton

private struct ExploreLoadingSkeleton: View {
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(0..<9, id: \.self) { _ in
                ShimmerView()
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}
