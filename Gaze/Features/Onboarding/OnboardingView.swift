import SwiftUI

// MARK: - Onboarding Root

struct OnboardingView: View {

    let onComplete: (StylePreferences) -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var preferences = StylePreferences()

    enum OnboardingStep: Int, CaseIterable {
        case welcome, styleQuiz, citySetup, profileSetup, pushPermission
    }

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()

            switch step {
            case .welcome:
                WelcomeView { nextStep() }
            case .styleQuiz:
                StyleQuizView(preferences: $preferences) { nextStep() }
            case .citySetup:
                CitySetupView(preferences: $preferences) { nextStep() }
            case .profileSetup:
                ProfileSetupView(preferences: $preferences) { nextStep() }
            case .pushPermission:
                PushPermissionView { onComplete(preferences) }
            }
        }
        .animation(GazeAnimations.standard, value: step)
    }

    private func nextStep() {
        GazeHaptics.light()
        guard let current = OnboardingStep.allCases.firstIndex(of: step),
              current + 1 < OnboardingStep.allCases.count else {
            onComplete(preferences)
            return
        }
        withAnimation(GazeAnimations.spring) {
            step = OnboardingStep.allCases[current + 1]
        }
    }
}

// MARK: - Welcome Screen

private struct WelcomeView: View {

    let onContinue: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A0A0A"), Color(hex: "#1A1400"), Color(hex: "#0A0A0A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.gazeAccent.opacity(0.12))
                            .frame(width: 110, height: 110)
                            .blur(radius: 28)

                        Text("G")
                            .font(.system(size: 68, weight: .black))
                            .foregroundStyle(Color.gazeAccent)
                    }

                    VStack(spacing: 8) {
                        Text("GAZE")
                            .font(.system(size: 44, weight: .black))
                            .foregroundStyle(Color.gazeTextPrimary)
                            .tracking(12)

                        Text("The fashion social network")
                            .font(GazeType.bodyLarge)
                            .foregroundStyle(Color.gazeTextSecondary)
                    }
                }
                .scaleEffect(appeared ? 1.0 : 0.88)
                .opacity(appeared ? 1.0 : 0.0)

                Spacer()

                VStack(spacing: 14) {
                    FeatureRow(icon: "person.2.fill", color: Color.gazeIce, text: "See your friends' fits")
                    FeatureRow(icon: "safari.fill", color: Color.gazeAccent, text: "Discover global style")
                    FeatureRow(icon: "trophy.fill", color: Color(hex: "#D4AF37"), text: "Climb the style ranking")
                }
                .padding(.horizontal, 32)
                .opacity(appeared ? 1.0 : 0.0)
                .offset(y: appeared ? 0 : 18)

                Spacer().frame(height: 44)

                GazeButton(label: "Enter the gaze", icon: "arrow.right") { onContinue() }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1.0 : 0.0)
                    .offset(y: appeared ? 0 : 18)

                Spacer().frame(height: 52)
            }
        }
        .onAppear {
            withAnimation(GazeAnimations.slow) { appeared = true }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(GazeType.bodyMedium)
                .foregroundStyle(Color.gazeTextPrimary)
            Spacer()
        }
    }
}

// MARK: - Style Quiz

struct StyleQuizView: View {

    @Binding var preferences: StylePreferences
    let onContinue: () -> Void
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                OnboardingHeader(
                    step: "01",
                    title: "Your style,\nyour identity.",
                    subtitle: "Pick what resonates. We'll build your feed around it."
                )
                .opacity(appeared ? 1.0 : 0.0)
                .offset(y: appeared ? 0 : 14)

                Spacer().frame(height: 36)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(StyleCategory.allCases, id: \.self) { cat in
                        StyleOptionCard(
                            category: cat,
                            isSelected: preferences.selectedCategories.contains(cat)
                        ) {
                            GazeHaptics.selection()
                            withAnimation(GazeAnimations.springSnappy) {
                                if preferences.selectedCategories.contains(cat) {
                                    preferences.selectedCategories.remove(cat)
                                } else {
                                    preferences.selectedCategories.insert(cat)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(GazeAnimations.spring.delay(0.1), value: appeared)

                Spacer().frame(height: 28)

                GazeButton(
                    label: preferences.selectedCategories.isEmpty ? "Skip for now" : "Continue",
                    icon: "arrow.right",
                    style: preferences.selectedCategories.isEmpty ? .ghost : .primary
                ) { onContinue() }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1.0 : 0.0)

                Spacer().frame(height: 48)
            }
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .onAppear { withAnimation(GazeAnimations.spring) { appeared = true } }
    }
}

private struct StyleOptionCard: View {
    let category: StyleCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? category.accentColor.opacity(0.16) : Color.gazeCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected ? category.accentColor : Color.gazeBorder,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )

                VStack(spacing: 10) {
                    Image(systemName: category.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isSelected ? category.accentColor : Color.gazeTextSecondary)

                    Text(category.rawValue)
                        .font(GazeType.labelLarge)
                        .foregroundStyle(isSelected ? Color.gazeTextPrimary : Color.gazeTextSecondary)
                        .multilineTextAlignment(.center)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(category.accentColor)
                    }
                }
                .padding(.vertical, 18)
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(GazeAnimations.springSnappy, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - City Setup

private struct CitySetupView: View {

    @Binding var preferences: StylePreferences
    let onContinue: () -> Void
    @State private var appeared = false
    @State private var customCity: String = ""
    @FocusState private var customCityFocused: Bool

    let cities = ["Berlin", "Paris", "Tokyo", "London", "Seoul", "Milan", "NYC",
                  "Zurich", "Madrid", "São Paulo", "Barcelona", "Amsterdam"]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            OnboardingHeader(
                step: "02",
                title: "Where are\nyou based?",
                subtitle: "Compete in your city's style ranking."
            )
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : 14)
            .padding(.horizontal, 24)

            Spacer().frame(height: 36)

            // Preset city chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cities, id: \.self) { city in
                        Button {
                            GazeHaptics.selection()
                            withAnimation(GazeAnimations.springSnappy) {
                                preferences.city = city
                                customCity = ""
                                customCityFocused = false
                            }
                        } label: {
                            Text(city)
                                .font(GazeType.labelLarge)
                                .foregroundStyle(preferences.city == city ? .black : Color.gazeTextSecondary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                                .background(
                                    Capsule()
                                        .fill(preferences.city == city ? Color.gazeAccent : Color.gazeCard)
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.gazeBorder, lineWidth: preferences.city == city ? 0 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
            .opacity(appeared ? 1.0 : 0.0)
            .animation(GazeAnimations.spring.delay(0.1), value: appeared)

            // Custom city text field
            VStack(alignment: .leading, spacing: 8) {
                Text("OR ENTER YOUR CITY")
                    .font(GazeType.labelSmall)
                    .foregroundStyle(Color.gazeTextMuted)
                    .tracking(1.5)

                HStack(spacing: 10) {
                    Image(systemName: "location")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.gazeTextMuted)

                    TextField("", text: $customCity,
                              prompt: Text("Type your city…").foregroundStyle(Color.gazeTextMuted))
                        .font(GazeType.bodyMedium)
                        .foregroundStyle(Color.gazeTextPrimary)
                        .focused($customCityFocused)
                        .autocorrectionDisabled()
                        .onChange(of: customCity) { _, newValue in
                            if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                                preferences.city = newValue.trimmingCharacters(in: .whitespaces)
                            }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.gazeCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            customCityFocused ? Color.gazeAccent.opacity(0.4) : Color.gazeBorder,
                            lineWidth: 1
                        )
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .opacity(appeared ? 1.0 : 0.0)

            Spacer()

            GazeButton(
                label: preferences.city.isEmpty ? "Skip" : "Continue",
                icon: "arrow.right",
                style: preferences.city.isEmpty ? .ghost : .primary
            ) { onContinue() }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
            .opacity(appeared ? 1.0 : 0.0)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .onAppear { withAnimation(GazeAnimations.spring) { appeared = true } }
    }
}

// MARK: - Profile Setup

private struct ProfileSetupView: View {

    @Binding var preferences: StylePreferences
    let onContinue: () -> Void
    @State private var appeared = false
    @FocusState private var focusedField: ProfileField?

    enum ProfileField { case username, displayName }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                OnboardingHeader(
                    step: "03",
                    title: "Set up\nyour profile.",
                    subtitle: "This is how the world sees you."
                )
                .padding(.horizontal, 24)
                .opacity(appeared ? 1.0 : 0.0)
                .offset(y: appeared ? 0 : 14)

                Spacer().frame(height: 44)

                VStack(spacing: 18) {
                    // Username — NO prefix parameter, placeholder contains @
                    OnboardingTextField(
                        label: "USERNAME",
                        placeholder: "@username",
                        text: $preferences.username
                    )
                    .focused($focusedField, equals: .username)

                    OnboardingTextField(
                        label: "DISPLAY NAME",
                        placeholder: "Your full name",
                        text: $preferences.displayName
                    )
                    .focused($focusedField, equals: .displayName)
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(GazeAnimations.spring.delay(0.1), value: appeared)

                Spacer().frame(height: 44)

                GazeButton(
                    label: "Let's go",
                    icon: "bolt.fill",
                    style: preferences.username.isEmpty ? .ghost : .primary
                ) { onContinue() }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
                .opacity(appeared ? 1.0 : 0.0)
            }
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .onAppear { withAnimation(GazeAnimations.spring) { appeared = true } }
    }
}

private struct OnboardingTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

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
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(16)
                .background(Color.gazeCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.gazeBorder, lineWidth: 1)
                )
        }
    }
}

// MARK: - Push Permission

private struct PushPermissionView: View {
    let onContinue: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#5856D6").opacity(0.12))
                        .frame(width: 110, height: 110)
                        .blur(radius: 18)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(Color(hex: "#5856D6"))
                }

                VStack(spacing: 12) {
                    Text("Stay in the loop")
                        .font(GazeType.displaySmall)
                        .foregroundStyle(Color.gazeTextPrimary)
                    Text("Get notified when your outfit fires,\nyou move up in rankings, or someone\nfollows you.")
                        .font(GazeType.bodyMedium)
                        .foregroundStyle(Color.gazeTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .opacity(appeared ? 1.0 : 0.0)
            .scaleEffect(appeared ? 1.0 : 0.92)

            Spacer()

            VStack(spacing: 12) {
                GazeButton(label: "Enable Notifications", icon: "bell.fill") { onContinue() }

                Button { onContinue() } label: {
                    Text("Maybe later")
                        .font(GazeType.bodySmall)
                        .foregroundStyle(Color.gazeTextMuted)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 56)
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : 18)
            .animation(GazeAnimations.spring.delay(0.2), value: appeared)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .onAppear { withAnimation(GazeAnimations.spring) { appeared = true } }
    }
}

// MARK: - Shared Onboarding Header

struct OnboardingHeader: View {
    let step: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STEP \(step)")
                .font(GazeType.labelSmall)
                .foregroundStyle(Color.gazeAccent)
                .tracking(2)

            Text(title)
                .font(GazeType.displayMedium)
                .foregroundStyle(Color.gazeTextPrimary)

            Text(subtitle)
                .font(GazeType.bodyMedium)
                .foregroundStyle(Color.gazeTextSecondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
