import SwiftUI

// MARK: - Username Setup (first-time profile creation after sign up)

struct UsernameSetupView: View {

    @EnvironmentObject private var appVM: AppViewModel

    let userId: UUID

    @State private var username = ""
    @State private var displayName = ""
    @State private var city = ""
    @State private var selectedCategory: StyleCategory = .minimalist
    @State private var usernameState: UsernameState = .idle
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?
    enum Field { case username, displayName, city }
    
    enum UsernameState { case idle, checking, available, taken }

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 60)

                    VStack(spacing: 8) {
                        Text("Set up your profile")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        Text("You can change this any time")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.gazeTextSecondary)
                    }

                    VStack(spacing: 18) {
                        // Username
                        fieldLabel("USERNAME")
                        HStack(spacing: 10) {
                            Text("@")
                                .foregroundStyle(Color.gazeTextMuted)
                                .font(.system(size: 16, weight: .medium))

                            TextField("", text: $username,
                                      prompt: Text("yourname").foregroundStyle(Color.gazeTextMuted))
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .username)
                                .onChange(of: username) { _, new in onUsernameChange(new) }

                            usernameIndicator
                        }
                        .padding(16)
                        .background(Color.gazeCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(usernameBorderColor, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { focusedField = .username }

                        // Display name
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("DISPLAY NAME")
                            TextField("", text: $displayName,
                                      prompt: Text("Your Name").foregroundStyle(Color.gazeTextMuted))
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .focused($focusedField, equals: .displayName)
                                .padding(16)
                                .background(Color.gazeCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.gazeBorder, lineWidth: 1)
                                )
                        }

                        // City
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("CITY")
                            TextField("", text: $city,
                                      prompt: Text("Berlin, Paris, Tokyo…").foregroundStyle(Color.gazeTextMuted))
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .focused($focusedField, equals: .city)
                                .padding(16)
                                .background(Color.gazeCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.gazeBorder, lineWidth: 1)
                                )
                        }

                        // Style
                        VStack(alignment: .leading, spacing: 10) {
                            fieldLabel("YOUR STYLE")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(StyleCategory.allCases, id: \.self) { cat in
                                        CategoryChip(category: cat, isSelected: selectedCategory == cat) {
                                            withAnimation(GazeAnimations.springSnappy) { selectedCategory = cat }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.gazeFire)
                            .padding(.horizontal, 24)
                    }

                    GazeButton(label: isSubmitting ? "Setting up…" : "Enter GAZE",
                               icon: isSubmitting ? nil : "arrow.right") {
                        submitProfile()
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .opacity(canSubmit ? 1 : 0.45)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.gazeTextMuted)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var usernameIndicator: some View {
        switch usernameState {
        case .checking:
            ProgressView().scaleEffect(0.7)
        case .available:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.gazeSuccess)
        case .taken:
            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.gazeFire)
        case .idle:
            EmptyView()
        }
    }

    private var usernameBorderColor: Color {
        switch usernameState {
        case .available: return Color.gazeSuccess.opacity(0.5)
        case .taken:     return Color.gazeFire.opacity(0.5)
        default:         return Color.gazeBorder
        }
    }

    private var canSubmit: Bool {
        !username.isEmpty && !displayName.isEmpty && usernameState == .available
    }

    // MARK: - Logic

    private func onUsernameChange(_ value: String) {
        usernameState = .idle
        let clean = value.trimmingCharacters(in: .whitespaces).lowercased()
        guard clean.count >= 3 else { return }
        usernameState = .checking

        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard username.lowercased() == clean else { return }
            do {
                let taken = try await SupabaseService.shared.isUsernameTaken(clean)
                usernameState = taken ? .taken : .available
            } catch {
                usernameState = .idle
            }
        }
    }

    private func submitProfile() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await SupabaseService.shared.createProfile(
                    id: userId,
                    username: username.lowercased().trimmingCharacters(in: .whitespaces),
                    displayName: displayName,
                    city: city,
                    styleCategory: selectedCategory
                )
                await appVM.onProfileCreated(
                    userId: userId,
                    username: username,
                    displayName: displayName,
                    city: city,
                    category: selectedCategory
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
