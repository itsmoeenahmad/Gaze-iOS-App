import SwiftUI
import PhotosUI
import UserNotifications

// MARK: - Profile View

struct ProfileView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @StateObject private var vm: ProfileViewModel
    @State private var showSettings = false
    @State private var showAvatarPicker = false
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var avatarPickerItem: PhotosPickerItem? = nil
    @State private var entryToDelete: ChallengeEntry? = nil
    @State private var rawAvatarImage: UIImage? = nil
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var lastFollowActionTime: Date = .distantPast

    init() {
        _vm = StateObject(wrappedValue: ProfileViewModel(user: MockDataService.shared.currentUser))
        // Real user is applied in onAppear via appVM.currentUser
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color.gazeBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Avatar + name + bio
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            GazeAvatar(user: vm.user, size: 80)

                            // Camera badge
                            ZStack {
                                Circle()
                                    .fill(Color.gazeCard)
                                    .frame(width: 26, height: 26)
                                    .overlay(Circle().strokeBorder(Color.gazeBorder, lineWidth: 1))
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.gazeTextPrimary)
                            }
                            .offset(x: 2, y: 2)
                        }
                        .onTapGesture { showAvatarPicker = true }
                        .confirmationDialog("Profile photo", isPresented: $showAvatarPicker) {
                            Button("Take Photo") { showCameraPicker = true }
                            Button("Choose from Library") { showLibraryPicker = true }
                            if vm.user.avatarURL != nil || MockDataService.shared.localAvatarImage(for: vm.user.id) != nil {
                                Button("Remove Photo", role: .destructive) {
                                    vm.removeAvatar()
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                        .fullScreenCover(isPresented: $showCameraPicker) {
                            AvatarCameraPickerView { image in
                                rawAvatarImage = image
                            }
                            .ignoresSafeArea()
                        }
                        .photosPicker(isPresented: $showLibraryPicker,
                                      selection: $avatarPickerItem,
                                      matching: .images)
                        .onChange(of: avatarPickerItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    rawAvatarImage = image
                                }
                            }
                        }

                        VStack(spacing: 4) {
                            Text(vm.user.displayName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.gazeTextPrimary)

                            Text("@\(vm.user.username)")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.gazeTextSecondary)
                        }

                        if !vm.user.bio.isEmpty {
                            Text(vm.user.bio)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.gazeTextSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.horizontal, 40)
                        }

                        // One-line stat row
                        HStack(spacing: 6) {
                            Text("\(vm.displayedPostCountForProfile) posts")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.gazeTextPrimary)
                            Text("·")
                                .foregroundStyle(Color.gazeTextMuted)
                                .font(.system(size: 12))
                            Button { showFollowers = true } label: {
                                Text("\(vm.user.followerCount.shortFormatted) followers")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.gazeTextPrimary)
                            }
                            .buttonStyle(.plain)
                            Text("·")
                                .foregroundStyle(Color.gazeTextMuted)
                                .font(.system(size: 12))
                            Button { showFollowing = true } label: {
                                Text("\(vm.user.followingCount.shortFormatted) following")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.gazeTextPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)

                        // Challenge wins badge
                        if vm.user.challengeWins > 0 {
                            HStack(spacing: 5) {
                                Text("🏆")
                                    .font(.system(size: 12))
                                Text("\(vm.user.challengeWins) challenge \(vm.user.challengeWins == 1 ? "win" : "wins")")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#D4AF37"))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#D4AF37").opacity(0.12))
                            .clipShape(Capsule())
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // Grid tab switcher
                    HStack(spacing: 0) {
                        ForEach(ProfileViewModel.ProfileGridTab.allCases, id: \.self) { tab in
                            Button {
                                GazeHaptics.selection()
                                withAnimation(GazeAnimations.springSnappy) {
                                    vm.activeGridTab = tab
                                }
                            } label: {
                                VStack(spacing: 0) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(
                                            vm.activeGridTab == tab
                                            ? Color.gazeTextPrimary
                                            : Color.gazeTextSecondary
                                        )
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)

                                    Rectangle()
                                        .fill(vm.activeGridTab == tab ? Color.gazeAccent : Color.clear)
                                        .frame(height: 1.5)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .overlay(
                        Rectangle()
                            .fill(Color.gazeBorder)
                            .frame(height: 1),
                        alignment: .bottom
                    )

                    // Photo grid
                    if vm.isLoading {
                        ProfileGridLoading()
                    } else if vm.activeGridTab == .arena {
                        ArenaGrid(
                            entries: vm.challengeEntries,
                            entryToDelete: $entryToDelete
                        )
                        .confirmationDialog("Remove from Arena?", isPresented: Binding(
                            get: { entryToDelete != nil },
                            set: { if !$0 { entryToDelete = nil } }
                        ), titleVisibility: .visible) {
                            Button("Remove", role: .destructive) {
                                if let entry = entryToDelete {
                                    withAnimation(GazeAnimations.springSnappy) {
                                        vm.deleteChallengeEntry(entry)
                                    }
                                    entryToDelete = nil
                                }
                            }
                            Button("Cancel", role: .cancel) { entryToDelete = nil }
                        }
                    } else if vm.displayedOutfits.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: vm.activeGridTab == .posts ? "camera" : "bookmark")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.gazeTextMuted)
                            Text(vm.activeGridTab == .posts ? "No outfits yet" : "Nothing saved")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.gazeTextSecondary)
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(vm.displayedOutfits) { outfit in
                                NavigationLink(value: outfit) {
                                    OutfitCard(outfit: outfit, cornerRadius: 0)
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipped()
                                }
                                .buttonStyle(GazePressStyle(scale: 0.97))
                            }
                        }
                    }

                    Spacer().frame(height: 100)
                }
            }
            .refreshable {
                await vm.loadAsync()
                guard !Task.isCancelled else { return }
                if let p = try? await SupabaseService.shared.fetchProfile(id: appVM.currentUser.id) {
                    let refreshed = p.toGazeUser()
                    appVM.currentUser.followerCount  = refreshed.followerCount
                    appVM.currentUser.followingCount = refreshed.followingCount
                    appVM.currentUser.outfitCount    = refreshed.outfitCount
                    vm.user = appVM.currentUser
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 52) }

            // Fixed top nav bar
            HStack {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color.gazeTextPrimary)
                }

                Spacer()

                Button { vm.showEditProfile = true } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color.gazeTextPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .background(Color.gazeBackground.opacity(0.95).ignoresSafeArea(edges: .top))
        }
        .preferredColorScheme(.light)
        .onAppear {
            vm.user = appVM.currentUser
            if vm.outfits.isEmpty {
                vm.load()
            } else {
                vm.refreshChallengeEntries()
            }
            let recentFollowAction = Date().timeIntervalSince(lastFollowActionTime) < 2
            if !recentFollowAction {
                Task {
                    if let p = try? await SupabaseService.shared.fetchProfile(id: appVM.currentUser.id) {
                        let refreshed = p.toGazeUser()
                        appVM.currentUser.followerCount  = refreshed.followerCount
                        appVM.currentUser.followingCount = refreshed.followingCount
                        appVM.currentUser.outfitCount    = refreshed.outfitCount
                        vm.user = appVM.currentUser
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gazeFollowingCountChanged)) { _ in
            lastFollowActionTime = Date()
        }
        .sheet(isPresented: $vm.showEditProfile) {
            EditProfileView(vm: vm)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showFollowers) {
            UserListSheet(title: "Followers", userId: vm.user.id, mode: .followers) { count in
                vm.user.followerCount = count
                appVM.currentUser.followerCount = count
            }
        }
        .sheet(isPresented: $showFollowing) {
            UserListSheet(title: "Following", userId: vm.user.id, mode: .following) { count in
                vm.user.followingCount = count
                appVM.currentUser.followingCount = count
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { rawAvatarImage != nil },
            set: { if !$0 { rawAvatarImage = nil } }
        )) {
            if let img = rawAvatarImage {
                AvatarCropView(
                    sourceImage: img,
                    onSave: { cropped in
                        rawAvatarImage = nil
                        vm.uploadAvatar(cropped)
                    },
                    onCancel: { rawAvatarImage = nil }
                )
            }
        }
        .alert("Upload Failed", isPresented: $vm.showAvatarUploadError) {
            Button("OK") {}
        } message: {
            Text("Your profile photo couldn't be saved. Please try again.")
        }
    }
}

// MARK: - Avatar Camera Picker

private struct AvatarCameraPickerView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let img = (info[.originalImage] ?? info[.editedImage]) as? UIImage
            picker.dismiss(animated: true) { [weak self] in
                if let img { self?.onImage(img) }
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Grid Loading

private struct ProfileGridLoading: View {
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(0..<9, id: \.self) { _ in
                ShimmerView()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(minHeight: 120)
            }
        }
    }
}

// MARK: - Arena Grid

private struct ArenaGrid: View {
    let entries: [ChallengeEntry]
    @Binding var entryToDelete: ChallengeEntry?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        if entries.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "trophy")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.gazeTextMuted)
                Text("No runway entries yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.gazeTextSecondary)
            }
            .padding(.top, 60)
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(entries) { entry in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                        ZStack(alignment: .topTrailing) {
                        Group {
                            if let outfit = entry.outfit {
                                NavigationLink(value: outfit) {
                                    ZStack(alignment: .bottomLeading) {
                                        OutfitCard(outfit: outfit, cornerRadius: 0)
                                            .clipped()
                                        Text("Wk \(entry.weekNumber)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.black.opacity(0.55))
                                            .clipShape(Capsule())
                                            .padding(5)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.gazeCard
                            }
                        }

                        // Delete button
                        Button {
                            entryToDelete = entry
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.45))
                                    .frame(width: 26, height: 26)
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(90))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(5)
                    }
                        )
                        .clipped()
                }
            }
        }
    }
}

// MARK: - Edit Profile

struct EditProfileView: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var bio = ""
    @State private var city = ""
    @State private var isSaving = false
    @State private var showSaveError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    GazeAvatar(user: vm.user, size: 80)
                        .padding(.top, 24)

                    VStack(spacing: 20) {
                        EditField(label: "DISPLAY NAME", text: $displayName, placeholder: "Your name")
                        EditField(label: "BIO", text: $bio, placeholder: "Short bio…")
                        EditField(label: "CITY", text: $city, placeholder: "Berlin, Paris, Tokyo…")
                    }
                    .padding(.horizontal, 24)

                    GazeButton(label: isSaving ? "Saving…" : "Save changes", icon: "checkmark") {
                        guard !isSaving else { return }
                        isSaving = true
                        Task {
                            let success = await vm.updateProfile(
                                displayName: displayName.isEmpty ? vm.user.displayName : displayName,
                                bio: bio.isEmpty ? vm.user.bio : bio,
                                city: city.isEmpty ? vm.user.city : city,
                                category: vm.user.styleCategory
                            )
                            isSaving = false
                            if success {
                                dismiss()
                            } else {
                                showSaveError = true
                            }
                        }
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.gazeBackground.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.gazeTextSecondary)
                }
            }
            .alert("Save Failed", isPresented: $showSaveError) {
                Button("OK") {}
            } message: {
                Text("Could not save your changes. Please try again.")
            }
            .preferredColorScheme(.light)
        }
        .onAppear {
            displayName = vm.user.displayName
            bio         = vm.user.bio
            city        = vm.user.city
        }
    }
}

private struct EditField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(GazeType.labelSmall)
                .foregroundStyle(Color.gazeTextMuted)
                .tracking(1.5)

            TextField("", text: $text,
                      prompt: Text(placeholder).foregroundStyle(Color.gazeTextMuted))
                .font(GazeType.bodyLarge)
                .foregroundStyle(Color.gazeTextPrimary)
                .padding(14)
                .background(Color.gazeCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.gazeBorder, lineWidth: 1)
                )
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRow(icon: "bell.fill", color: Color(hex: "#5856D6"), label: "Notifications")
                    }
                    .listRowBackground(Color.gazeCard)

                    NavigationLink {
                        BlockedUsersSettingsView()
                    } label: {
                        SettingsRow(icon: "hand.raised.fill", color: Color.gazeSuccess, label: "Blocked Users")
                    }
                    .listRowBackground(Color.gazeCard)
                }

                Section {
                    NavigationLink {
                        LegalDocumentView(title: "Terms of Service", icon: "doc.text.fill")
                    } label: {
                        SettingsRow(icon: "doc.text.fill", color: Color.gazeTextSecondary, label: "Terms of Service")
                    }
                    .listRowBackground(Color.gazeCard)

                    NavigationLink {
                        LegalDocumentView(title: "Privacy Policy", icon: "hand.raised.fill")
                    } label: {
                        SettingsRow(icon: "hand.raised.fill", color: Color.gazeTextSecondary, label: "Privacy Policy")
                    }
                    .listRowBackground(Color.gazeCard)
                }

                Section {
                    Button {
                        dismiss()
                        Task { await appVM.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                            .foregroundStyle(Color.gazeFire)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gazeBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.gazeAccent)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(GazeType.bodyMedium)
                .foregroundStyle(Color.gazeTextPrimary)
        }
    }
}

// MARK: - Notification Settings

private struct NotificationSettingsView: View {
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Push Notifications")
                        .font(GazeType.bodyMedium)
                        .foregroundStyle(Color.gazeTextPrimary)
                    Spacer()
                    Text(statusLabel)
                        .font(GazeType.bodyMedium)
                        .foregroundStyle(statusColor)
                }
                .listRowBackground(Color.gazeCard)
            } footer: {
                Text("GAZE shows your iOS push permission status only. There are no in-app notification toggles yet. To allow or deny alerts, use Open System Settings. If product adds per-channel controls later, they will be specified separately.")
                    .font(GazeType.bodySmall)
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Open System Settings")
                            .font(GazeType.bodyMedium)
                            .foregroundStyle(Color.gazeAccent)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.gazeAccent)
                    }
                }
                .listRowBackground(Color.gazeCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gazeBackground.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
        .task { await checkStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await checkStatus() }
        }
    }

    private var statusLabel: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "Enabled"
        case .denied: return "Disabled"
        default: return "Not Set"
        }
    }

    private var statusColor: Color {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return Color.gazeSuccess
        case .denied: return Color.gazeFire
        default: return Color.gazeTextSecondary
        }
    }

    private func checkStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
    }
}

// MARK: - Blocked Users Settings

private struct BlockedUsersSettingsView: View {
    @State private var blockedUsers: [GazeUser] = []
    @State private var isLoading = true
    @State private var unblockTarget: GazeUser?

    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 40)
                        Spacer()
                    }
                    .listRowBackground(Color.gazeCard)
                }
            } else if blockedUsers.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "hand.raised.slash")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.gazeTextMuted)
                            Text("No Blocked Users")
                                .font(GazeType.headlineSmall)
                                .foregroundStyle(Color.gazeTextPrimary)
                            Text("Users you block will appear here.")
                                .font(GazeType.bodySmall)
                                .foregroundStyle(Color.gazeTextSecondary)
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                    .listRowBackground(Color.gazeCard)
                }
            } else {
                Section {
                    ForEach(blockedUsers) { user in
                        HStack(spacing: 12) {
                            GazeAvatar(user: user, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(GazeType.bodyMedium)
                                    .foregroundStyle(Color.gazeTextPrimary)
                                Text("@\(user.username)")
                                    .font(GazeType.bodySmall)
                                    .foregroundStyle(Color.gazeTextSecondary)
                            }
                            Spacer()
                            Button {
                                unblockTarget = user
                            } label: {
                                Text("Unblock")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.gazeAccent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .strokeBorder(Color.gazeAccent, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color.gazeCard)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gazeBackground.ignoresSafeArea())
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
        .task { await loadBlockedUsers() }
        .refreshable { await loadBlockedUsers() }
        .confirmationDialog(
            "Unblock \(unblockTarget?.displayName ?? "this user")?",
            isPresented: Binding(
                get: { unblockTarget != nil },
                set: { if !$0 { unblockTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Unblock", role: .destructive) {
                if let user = unblockTarget {
                    performUnblock(user: user)
                }
            }
            Button("Cancel", role: .cancel) { unblockTarget = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gazeUserBlocked)) { _ in
            Task { await loadBlockedUsers() }
        }
    }

    private func loadBlockedUsers() async {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        do {
            blockedUsers = try await SupabaseService.shared.fetchBlockedUsers(userId: userId)
        } catch {
            print("[BlockedUsers] fetch error: \(error)")
        }
        isLoading = false
    }

    private func performUnblock(user: GazeUser) {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        blockedUsers.removeAll { $0.id == user.id }
        Task {
            do {
                try await SupabaseService.shared.unblockUser(blockerId: userId, blockedId: user.id)
                NotificationCenter.default.post(name: .gazeUserBlocked, object: nil)
            } catch {
                blockedUsers.append(user)
                print("[BlockedUsers] unblock error: \(error)")
            }
        }
    }
}

// MARK: - Legal Document View

private struct LegalDocumentView: View {
    let title: String
    let icon: String

    var body: some View {
        ScrollView {
            Text(content)
                .font(GazeType.bodyMedium)
                .foregroundStyle(Color.gazeTextPrimary)
                .padding()
        }
        .background(Color.gazeBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
    }

    private var content: String {
        switch title {
        case "Privacy Policy": return Self.privacyPolicy
        case "Terms of Service": return Self.termsOfService
        default: return ""
        }
    }

    private static let privacyPolicy = """
(Last updated: March 19, 2026)

GAZE ("we", "us", or "our") collects only what's needed to run the app. We don't sell your data. You can delete your account and all associated data at any time.

1. Information We Collect

You provide directly:

Email address, username, display name, and password when you register
Profile information: bio, city, style category, and profile photo
Content: outfit photos, captions, comments, and challenge submissions

Collected automatically:

Usage data: screens visited, features used, actions taken (likes, saves, follows)
Device information: device type, OS version, device identifiers
Log data: IP address, timestamps, and error reports

2. How We Use Your Information

Create and manage your account and authenticate your identity
Display your profile, posts, and interactions to other users
Power the Friends feed, Following feed, Explore, and weekly challenges
Send in-app notifications (likes, comments, new followers, challenge results)
Improve the app, fix bugs, and develop new features
Detect and prevent fraud or abuse
Comply with legal obligations

3. How We Share Your Information

With other users: Your username, profile photo, bio, and public posts are visible to other users. Posts set to "Friends only" are visible only to mutual followers.

With service providers: We use Supabase for database, authentication, and file storage. They access your data only to provide these services and are bound by confidentiality obligations. See supabase.com/privacy.

For legal reasons: We may disclose your information if required by law or to protect the rights, property, or safety of GAZE or its users.

We do not sell, rent, or trade your personal information to any third party.

4. Data Retention

We retain your data for as long as your account is active. If you delete your account, your personal information is deleted within 30 days.

5. Your Rights

You may request to access, correct, delete, or export your personal data at any time by contacting office@swixai.info. We will respond within 30 days.

6. Children's Privacy

GAZE is not intended for anyone under 13. We do not knowingly collect data from children under 13. Contact us immediately if you believe this has occurred.

7. Security

We use encrypted connections (HTTPS/TLS) for all data in transit and secure, access-controlled storage for data at rest.

8. Changes to This Policy

We may update this policy from time to time. We will notify users of material changes via the app or email.

9. Contact

office@swixai.info
"""

    private static let termsOfService = """
(Last updated: March 19, 2026)

1. Eligibility

You must be at least 13 years old to use GAZE. Users under 18 must have parental permission.

2. Your Account

You are responsible for all activity under your account. You agree to provide accurate information, keep your password confidential, and not create multiple accounts to bypass restrictions. Contact office@swixai.info immediately if you believe your account has been compromised.

3. Your Content

You retain ownership of content you post. By posting, you grant GAZE a non-exclusive, worldwide, royalty-free license to display and distribute your content solely for operating the app. You are responsible for ensuring you have the rights to post what you share.

4. Prohibited Conduct

You may not use GAZE to post illegal, hateful, threatening, harassing, defamatory, or pornographic content; impersonate others; share someone else's private information without consent; spam or use automated activity; attempt to access or disrupt our servers; reverse engineer the app; or use the app for commercial purposes without permission.

5. Intellectual Property

All intellectual property in the app — design, code, the GAZE name and logo — is owned by or licensed to us. Nothing in these Terms grants you rights to use our brand elements.

6. Disclaimers

The app is provided "as is" without warranties of any kind. We do not guarantee the app will be uninterrupted or error-free.

7. Limitation of Liability

To the fullest extent permitted by law, GAZE shall not be liable for any indirect, incidental, or consequential damages arising from your use of the app.

8. Termination

We may suspend or terminate your account at any time for violations of these Terms. You may delete your account at any time through Settings.

9. Governing Law

These Terms are governed by applicable law. If any provision is found unenforceable, the remaining provisions remain in effect.

10. Changes to These Terms

We may update these Terms. Material changes will be communicated via the app or email. Continued use constitutes acceptance.

11. Contact

office@swixai.info
"""
}

// MARK: - Followers / Following Sheet

struct UserListSheet: View {
    enum Mode { case followers, following }

    let title: String
    let userId: UUID
    let mode: Mode
    var onCountLoaded: ((Int) -> Void)? = nil

    @State private var users: [GazeUser] = []
    @State private var isLoading = true
    @State private var selectedUser: GazeUser? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gazeBackground.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if users.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.gazeTextMuted)
                        Text("No \(title.lowercased()) yet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.gazeTextSecondary)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(users) { user in
                                Button { selectedUser = user } label: {
                                    HStack(spacing: 12) {
                                        GazeAvatar(user: user, size: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("@\(user.username)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.gazeTextPrimary)
                                            if !user.city.isEmpty {
                                                Text(user.city)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.gazeTextSecondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer().frame(height: 40)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
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
        .onAppear { Task { await loadUsers() } }
        .refreshable { await loadUsers() }
    }

    private func loadUsers() async {
        do {
            users = mode == .followers
                ? try await SupabaseService.shared.fetchFollowers(userId: userId)
                : try await SupabaseService.shared.fetchFollowing(userId: userId)
            onCountLoaded?(users.count)
        } catch {
            users = []
        }
        isLoading = false
    }
}

// MARK: - Avatar Crop View

private struct AvatarCropView: View {
    let sourceImage: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero

    private let cropDiameter: CGFloat = 280

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                // Image layer — fills screen, user scales and drags
                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale)
                    .offset(dragOffset)
                    .clipped()
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let proposed = CGSize(
                                    width:  lastDragOffset.width  + value.translation.width,
                                    height: lastDragOffset.height + value.translation.height
                                )
                                dragOffset = clampOffset(proposed, scale: scale, in: geo.size)
                            }
                            .onEnded { _ in lastDragOffset = dragOffset }
                    )
                    .simultaneousGesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let proposed = max(1.0, min(5.0, lastScale * value.magnification))
                                scale = proposed
                                dragOffset = clampOffset(dragOffset, scale: proposed, in: geo.size)
                            }
                            .onEnded { _ in lastScale = scale }
                    )

                // Dark overlay with circular cutout
                ZStack {
                    Color.black.opacity(0.55)
                    Circle()
                        .frame(width: cropDiameter, height: cropDiameter)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.75), lineWidth: 1.5)
                        .frame(width: cropDiameter, height: cropDiameter)
                )
                .allowsHitTesting(false)

                // Chrome
                VStack {
                    HStack {
                        Button("Cancel") { onCancel() }
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)

                        Spacer()

                        Button("Upload") {
                            onSave(buildCrop(in: geo.size))
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .padding(.top, 50)

                    Spacer()

                    Text("Move and pinch to position")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.bottom, 50)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    /// Keeps the image covering the crop circle at all times
    private func clampOffset(_ offset: CGSize, scale: CGFloat, in screen: CGSize) -> CGSize {
        let iw = sourceImage.size.width
        let ih = sourceImage.size.height
        let base = max(screen.width / iw, screen.height / ih)
        let total = base * scale
        let maxX = max(0, iw * total / 2 - cropDiameter / 2)
        let maxY = max(0, ih * total / 2 - cropDiameter / 2)
        return CGSize(
            width:  max(-maxX, min(maxX, offset.width)),
            height: max(-maxY, min(maxY, offset.height))
        )
    }

    /// Renders the exact pixels visible inside the crop circle
    private func buildCrop(in screen: CGSize) -> UIImage {
        let src = sourceImage.normalized()
        let iw = src.size.width
        let ih = src.size.height
        let base = max(screen.width / iw, screen.height / ih)
        let total = base * scale

        // Center of crop circle mapped back to image-point coordinates
        let cx = iw / 2 - dragOffset.width  / total
        let cy = ih / 2 - dragOffset.height / total
        let side = cropDiameter / total

        let cropRect = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)

        // cgImage works in pixels; src.size is in points
        let px = src.scale
        let pixelRect = CGRect(
            x: cropRect.minX * px, y: cropRect.minY * px,
            width: cropRect.width * px, height: cropRect.height * px
        )

        guard let cgImg = src.cgImage,
              let cropped = cgImg.cropping(to: pixelRect) else { return sourceImage }
        return UIImage(cgImage: cropped, scale: px, orientation: .up)
    }
}

// MARK: - UIImage orientation fix

private extension UIImage {
    /// Returns a copy of the image with orientation = .up (normalizes EXIF rotation)
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}
