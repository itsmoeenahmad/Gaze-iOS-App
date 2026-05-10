import SwiftUI

// MARK: - Auth View (Sign in / Sign up)

struct AuthView: View {

    @EnvironmentObject private var appVM: AppViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showForgotPassword = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Background tap dismisses keyboard without eating child taps
            Color.gazeBackground
                .ignoresSafeArea()
                .onTapGesture { focusedField = nil }

            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 10) {
                    Text("GAZE")
                        .font(.system(size: 52, weight: .black))
                        .foregroundStyle(Color.gazeTextPrimary)
                        .kerning(10)
                    Text("dress. post. get rated.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.gazeTextSecondary)
                        .kerning(0.5)
                }

                Spacer().frame(height: 64)

                // Form
                VStack(spacing: 14) {
                    // Email
                    TextField("", text: $email,
                              prompt: Text("Email").foregroundStyle(Color.gazeTextMuted))
                        .font(.system(size: 16))
                        .foregroundStyle(Color.gazeTextPrimary)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .padding(16)
                        .background(Color.gazeCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    focusedField == .email ? Color.gazeAccent.opacity(0.5) : Color.gazeBorder,
                                    lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture { focusedField = .email }

                    // Password
                    SecureField("", text: $password,
                                prompt: Text("Password (min 6 chars)").foregroundStyle(Color.gazeTextMuted))
                        .font(.system(size: 16))
                        .foregroundStyle(Color.gazeTextPrimary)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit { submit() }
                        .padding(16)
                        .background(Color.gazeCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    focusedField == .password ? Color.gazeAccent.opacity(0.5) : Color.gazeBorder,
                                    lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture { focusedField = .password }

                    // Error / Success
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.gazeFire)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                    if let success = successMessage {
                        Text(success)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.gazeSuccess)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                    // Submit button
                    Button(action: submit) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(canSubmit ? Color.gazeAccent : Color.gazeAccent.opacity(0.25))
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(isSignUp ? "Create account" : "Sign in")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(canSubmit ? .white : Color.gazeTextMuted)
                            }
                        }
                        .frame(height: 52)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || isLoading)
                    .animation(.easeInOut(duration: 0.15), value: canSubmit)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 28)

                // Toggle mode
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSignUp.toggle()
                        errorMessage = nil
                        successMessage = nil
                    }
                } label: {
                    Group {
                        if isSignUp {
                            Text("Already have an account? ") + Text("Sign in").bold()
                        } else {
                            Text("No account yet? ") + Text("Sign up").bold()
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Color.gazeTextSecondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Forgot password (sign in only)
                if !isSignUp {
                    Button {
                        showForgotPassword = true
                    } label: {
                        Text("Forgot password?")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.gazeAccent)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet()
        }
    }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6
    }

    private func submit() {
        guard canSubmit else { return }
        focusedField = nil
        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                if isSignUp {
                    let userId = try await SupabaseService.shared.signUp(email: email, password: password)
                    await appVM.onSignedUp(userId: userId)
                } else {
                    try await SupabaseService.shared.signIn(email: email, password: password)
                    await appVM.onSignedIn()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Forgot Password Sheet

private struct ForgotPasswordSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var sent = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gazeBackground.ignoresSafeArea()
                    .onTapGesture { focused = false }

                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    VStack(spacing: 8) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(Color.gazeAccent)
                        Text("Reset your password")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.gazeTextPrimary)
                        Text("Enter your email and we'll send you a reset link.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.gazeTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    if sent {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.gazeSuccess)
                            Text("Email sent!")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.gazeTextPrimary)
                            Text("Check your inbox and follow the link to reset your password.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.gazeTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 10)
                    } else {
                        VStack(spacing: 14) {
                            TextField("", text: $email,
                                      prompt: Text("Email address").foregroundStyle(Color.gazeTextMuted))
                                .font(.system(size: 16))
                                .foregroundStyle(Color.gazeTextPrimary)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($focused)
                                .padding(16)
                                .background(Color.gazeCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            focused ? Color.gazeAccent.opacity(0.5) : Color.gazeBorder,
                                            lineWidth: 1)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .onTapGesture { focused = true }

                            if let error = errorMessage {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.gazeFire)
                                    .multilineTextAlignment(.center)
                            }

                            Button(action: sendReset) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(email.isEmpty ? Color.gazeAccent.opacity(0.25) : Color.gazeAccent)
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Send reset link")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(email.isEmpty ? Color.gazeTextMuted : .white)
                                    }
                                }
                                .frame(height: 52)
                                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(email.isEmpty || isLoading)
                        }
                        .padding(.horizontal, 28)
                    }

                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.gazeAccent)
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func sendReset() {
        guard !email.isEmpty else { return }
        focused = false
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await SupabaseService.shared.resetPassword(email: email)
                await MainActor.run { sent = true }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isLoading = false }
        }
    }
}
