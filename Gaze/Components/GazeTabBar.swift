import SwiftUI

// MARK: - Custom Tab Bar

struct GazeTabBar: View {

    @Binding var selectedTab: GazeTab
    let onPostTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GazeTab.allCases, id: \.self) { tab in
                if tab == .post {
                    // Center post button — elevated gold pill
                    Button {
                        GazeHaptics.medium()
                        onPostTap()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.gazeAccent)
                                .frame(width: 52, height: 52)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)

                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .offset(y: -8)
                } else {
                    TabBarItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        GazeHaptics.selection()
                        withAnimation(GazeAnimations.springSnappy) {
                            selectedTab = tab
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            ZStack {
                Color.gazeSurface
                Color.gazeBackground.opacity(0.8)
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Rectangle()
                .fill(Color.gazeBorder.opacity(0.6))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

private struct TabBarItem: View {
    let tab: GazeTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.gazeAccent.opacity(0.12))
                            .frame(width: 36, height: 28)
                    }
                    Image(systemName: isSelected ? tab.icon : tab.unselectedIcon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.gazeAccent : Color.gazeTextSecondary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }

                Text(tab.label)
                    .font(GazeType.labelSmall)
                    .foregroundStyle(isSelected ? Color.gazeAccent : Color.gazeTextMuted)
                    .opacity(isSelected ? 1 : 0.7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .animation(GazeAnimations.springSnappy, value: isSelected)
        }
        .buttonStyle(GazePressStyle(scale: 0.92))
    }
}
