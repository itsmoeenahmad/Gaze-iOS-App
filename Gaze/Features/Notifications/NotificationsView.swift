import SwiftUI

// MARK: - Notifications View

struct NotificationsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel
    @State private var notifications: [GazeNotification] = []
    @State private var handledRequestFromIds: Set<UUID> = []
    @State private var appeared = false
    @State private var selectedUser: GazeUser? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gazeBackground.ignoresSafeArea()

                if notifications.isEmpty && appeared {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(notifications.enumerated()), id: \.element.id) { idx, notif in
                                NotificationRow(
                                    notification: notif,
                                    isRequestHandled: handledRequestFromIds.contains(notif.fromUser.id),
                                    onAccept: notif.type == .friendRequest ? { acceptRequest(from: notif) } : nil,
                                    onDecline: notif.type == .friendRequest ? { declineRequest(from: notif) } : nil
                                )
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 20)
                                    .animation(GazeAnimations.spring.delay(Double(idx) * 0.05), value: appeared)
                                    // Use simultaneousGesture so child buttons still fire
                                    .simultaneousGesture(TapGesture().onEnded {
                                        markRead(id: notif.id)
                                        selectedUser = notif.fromUser
                                    })

                                if idx < notifications.count - 1 {
                                    Divider().background(Color.gazeBorder).padding(.leading, 72)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .refreshable { await reloadNotifications() }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.gazeTextSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mark all read") {
                        let unread = notifications.filter { !$0.isRead }
                        withAnimation(GazeAnimations.standard) {
                            notifications = notifications.map { var n = $0; n.isRead = true; return n }
                        }
                        Task {
                            for notif in unread {
                                try? await SupabaseService.shared.markNotificationRead(id: notif.id)
                            }
                        }
                    }
                    .font(GazeType.labelLarge)
                    .foregroundStyle(Color.gazeAccent)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedUser != nil },
                set: { if !$0 { selectedUser = nil } }
            )) {
                if let user = selectedUser { UserProfileView(user: user) }
            }
            .preferredColorScheme(.light)
        }
        .onAppear {
            Task {
                guard let userId = SupabaseManager.shared.currentUserId else {
                    withAnimation(GazeAnimations.spring.delay(0.1)) { appeared = true }
                    return
                }
                do {
                    notifications = try await SupabaseService.shared.fetchNotifications(userId: userId)
                } catch {
                    notifications = []
                }
                withAnimation(GazeAnimations.spring.delay(0.1)) { appeared = true }
            }
        }
        .onDisappear {
            Task { await appVM.refreshNotificationCount() }
        }
    }

    @MainActor
    private func reloadNotifications() async {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        if let fetched = try? await SupabaseService.shared.fetchNotifications(userId: userId) {
            notifications = fetched
        }
    }

    private func acceptRequest(from notif: GazeNotification) {
        guard let currentId = SupabaseManager.shared.currentUserId else { return }
        GazeHaptics.success()
        withAnimation(GazeAnimations.spring) {
            _ = handledRequestFromIds.insert(notif.fromUser.id)
        }
        Task {
            do {
                try await SupabaseService.shared.acceptFriendRequest(fromUserId: notif.fromUser.id, toUserId: currentId)
            } catch {
                withAnimation(GazeAnimations.spring) {
                    handledRequestFromIds.remove(notif.fromUser.id)
                }
            }
        }
    }

    private func declineRequest(from notif: GazeNotification) {
        guard let currentId = SupabaseManager.shared.currentUserId else { return }
        GazeHaptics.light()
        withAnimation(GazeAnimations.spring) {
            _ = handledRequestFromIds.insert(notif.fromUser.id)
        }
        Task {
            do {
                try await SupabaseService.shared.declineFriendRequest(fromUserId: notif.fromUser.id, toUserId: currentId)
            } catch {
                withAnimation(GazeAnimations.spring) {
                    handledRequestFromIds.remove(notif.fromUser.id)
                }
            }
        }
    }

    private func markRead(id: UUID) {
        guard let idx = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[idx].isRead = true
        Task { try? await SupabaseService.shared.markNotificationRead(id: id) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.gazeTextMuted)
            Text("All caught up")
                .font(GazeType.headlineLarge)
                .foregroundStyle(Color.gazeTextSecondary)
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: GazeNotification
    var isRequestHandled: Bool = false
    var onAccept: (() -> Void)? = nil
    var onDecline: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            // User avatar with type badge
            ZStack(alignment: .bottomTrailing) {
                GazeAvatar(user: notification.fromUser, size: 48)

                ZStack {
                    Circle()
                        .fill(Color.gazeBackground)
                        .frame(width: 22, height: 22)
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(notification.type.color)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("@\(notification.fromUser.username)")
                        .font(GazeType.labelLarge)
                        .foregroundStyle(Color.gazeTextPrimary)
                    Text(notification.message)
                        .font(GazeType.bodySmall)
                        .foregroundStyle(Color.gazeTextSecondary)
                        .lineLimit(2)
                }

                Text(notification.timestamp.timeAgoString)
                    .font(GazeType.labelSmall)
                    .foregroundStyle(Color.gazeTextMuted)

                // Accept/Decline for friend requests
                if notification.type == .friendRequest {
                    if isRequestHandled {
                        Text("Responded")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.gazeTextMuted)
                    } else {
                        HStack(spacing: 8) {
                            Button {
                                onAccept?()
                            } label: {
                                Text("Accept")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.gazeAccent))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                onDecline?()
                            } label: {
                                Text("Decline")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.gazeTextSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(Color.gazeCard)
                                            .overlay(Capsule().strokeBorder(Color.gazeBorder, lineWidth: 1))
                                    )
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    }
                }
            }

            Spacer()

            // Outfit thumbnail if present (not for friend requests)
            if notification.type != .friendRequest, let outfit = notification.outfit {
                OutfitGradientCard(gradientIndex: outfit.gradientIndex, cornerRadius: 8)
                    .frame(width: 44, height: 56)
                    .opacity(0.8)
            }

            // Unread dot
            if !notification.isRead {
                Circle()
                    .fill(Color.gazeAccent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(notification.isRead ? Color.clear : Color.gazeAccent.opacity(0.04))
        .animation(GazeAnimations.standard, value: notification.isRead)
    }
}

extension Date {
    var timeAgoString: String {
        let diff = Date().timeIntervalSince(self)
        switch diff {
        case ..<60:         return "just now"
        case ..<3600:       return "\(Int(diff/60))m ago"
        case ..<86400:      return "\(Int(diff/3600))h ago"
        default:            return "\(Int(diff/86400))d ago"
        }
    }
}
