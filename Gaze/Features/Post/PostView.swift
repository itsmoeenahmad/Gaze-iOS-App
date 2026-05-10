import SwiftUI
import PhotosUI

// MARK: - Post View

struct PostView: View {

    @ObservedObject var vm: PostViewModel
    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.gazeBackground.ignoresSafeArea()

            switch vm.step {
            case .camera:
                PostCameraView(vm: vm)
            case .compose:
                PostComposeView(vm: vm)
            case .preview:
                PostPreviewView(vm: vm)
            case .publishing:
                PostPublishingView(progress: vm.publishProgress)
            case .success:
                PostSuccessView(outfit: vm.publishedOutfit, image: vm.selectedImage) {
                    vm.reset()
                    dismiss()
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if vm.step == .camera || vm.step == .compose || vm.step == .preview {
                Button {
                    switch vm.step {
                    case .compose:  vm.retake()
                    case .preview:  withAnimation(GazeAnimations.spring) { vm.step = .compose }
                    default:        dismiss()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 38, height: 38)
                        Image(systemName: vm.step == .camera ? "xmark" : "arrow.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 56)
                .padding(.leading, 20)
            }
        }
        .overlay(alignment: .topTrailing) {
            if vm.step == .compose {
                let canContinue = !vm.caption.trimmingCharacters(in: .whitespaces).isEmpty && vm.canPost
                Button {
                    withAnimation(GazeAnimations.spring) { vm.step = .preview }
                } label: {
                    Text("Continue")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canContinue ? .black : Color.gazeTextMuted)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(canContinue ? Color.gazeAccent : Color.gazeCard)
                        )
                }
                .disabled(!canContinue)
                .padding(.top, 56)
                .padding(.trailing, 20)
            }
        }
        .animation(GazeAnimations.spring, value: vm.step)
        .alert("Post Failed", isPresented: Binding(
            get: { vm.publishError != nil },
            set: { if !$0 { vm.publishError = nil } }
        )) {
            Button("OK", role: .cancel) { vm.publishError = nil }
        } message: {
            Text(vm.publishError ?? "")
        }
    }
}

// MARK: - Camera / Pick Step

private struct PostCameraView: View {

    @ObservedObject var vm: PostViewModel
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showCameraPicker = false

    var body: some View {
        ZStack {
            Color.gazeBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Text("New Outfit")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.gazeTextPrimary)
                    Text("Choose how to add your photo")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.gazeTextSecondary)
                }

                VStack(spacing: 14) {
                    // Camera button
                    Button { showCameraPicker = true } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.gazeCard)
                                    .frame(width: 48, height: 48)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color.gazeTextPrimary)
                            }
                            Text("Take Photo")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.gazeTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.gazeTextMuted)
                        }
                        .padding(16)
                        .background(Color.gazeCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.gazeBorder, lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // Gallery button
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.gazeCard)
                                    .frame(width: 48, height: 48)
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color.gazeTextPrimary)
                            }
                            Text("Choose from Library")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.gazeTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.gazeTextMuted)
                        }
                        .padding(16)
                        .background(Color.gazeCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.gazeBorder, lineWidth: 1)
                        )
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                vm.selectedImage = image
                                vm.capturedGradientIndex = Int.random(in: 0..<GazeGradients.outfitPalettes.count)
                                withAnimation(GazeAnimations.spring) { vm.step = .compose }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker, onDismiss: {
            if vm.selectedImage != nil && vm.step == .camera {
                withAnimation(GazeAnimations.spring) { vm.step = .compose }
            }
        }) {
            CameraPickerView { image in
                vm.selectedImage = image
                vm.capturedGradientIndex = Int.random(in: 0..<GazeGradients.outfitPalettes.count)
                showCameraPicker = false
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Real Camera (UIImagePickerController)

struct CameraPickerView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let img = info[.originalImage] as? UIImage else {
                picker.dismiss(animated: true)
                return
            }
            picker.dismiss(animated: true) { [weak self] in
                self?.onImage(img)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Compose Step

private struct PostComposeView: View {

    @ObservedObject var vm: PostViewModel
    @EnvironmentObject private var appVM: AppViewModel
    @FocusState private var captionFocused: Bool
    @FocusState private var brandFocused: Bool
    @FocusState private var linkFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 72)

                // Photo thumbnail + title
                HStack(spacing: 16) {
                    Group {
                        if let image = vm.selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            OutfitGradientCard(gradientIndex: vm.capturedGradientIndex, cornerRadius: 0)
                        }
                    }
                    .frame(width: 80, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 5)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("New outfit")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.gazeTextPrimary)

                        if !vm.canPost {
                            Text("Daily limit reached (2/2)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.gazeFire)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(Color.gazeFire.opacity(0.12))
                                )
                        } else {
                            Text("\(vm.dailyPostCount)/2 posts today")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.gazeTextSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 28)

                VStack(spacing: 22) {
                    // Caption
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CAPTION")
                            .font(GazeType.labelSmall)
                            .foregroundStyle(Color.gazeTextMuted)
                            .tracking(1.5)

                        TextField("", text: $vm.caption,
                                  prompt: Text("Describe your fit…").foregroundStyle(Color.gazeTextMuted),
                                  axis: .vertical)
                            .font(GazeType.bodyLarge)
                            .foregroundStyle(Color.gazeTextPrimary)
                            .focused($captionFocused)
                            .lineLimit(3...5)
                            .padding(14)
                            .background(Color.gazeCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        captionFocused ? Color.gazeAccent.opacity(0.4) : Color.gazeBorder,
                                        lineWidth: 1
                                    )
                            )
                    }

                    // Product / shop link (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRODUCT LINK")
                            .font(GazeType.labelSmall)
                            .foregroundStyle(Color.gazeTextMuted)
                            .tracking(1.5)

                        TextField("", text: $vm.productLink,
                                  prompt: Text("https://… or domain only (optional)").foregroundStyle(Color.gazeTextMuted))
                            .font(GazeType.bodyLarge)
                            .foregroundStyle(Color.gazeTextPrimary)
                            .focused($linkFocused)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color.gazeCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        linkFocused ? Color.gazeAccent.opacity(0.4) : Color.gazeBorder,
                                        lineWidth: 1
                                    )
                            )
                    }

                    // Visibility toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Text("VISIBILITY")
                            .font(GazeType.labelSmall)
                            .foregroundStyle(Color.gazeTextMuted)
                            .tracking(1.5)

                        Picker("Visibility", selection: $vm.selectedVisibility) {
                            Text("Friends").tag(PostVisibility.friends)
                            Text("Everyone").tag(PostVisibility.everyone)
                        }
                        .pickerStyle(.segmented)
                        .tint(Color.gazeAccent)
                    }

                    // Brand tags (collapsible)
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            GazeHaptics.light()
                            withAnimation(GazeAnimations.springSnappy) {
                                vm.showBrandSection.toggle()
                            }
                        } label: {
                            HStack {
                                Text("BRAND TAGS")
                                    .font(GazeType.labelSmall)
                                    .foregroundStyle(Color.gazeTextMuted)
                                    .tracking(1.5)
                                Text("(optional)")
                                    .font(GazeType.labelSmall)
                                    .foregroundStyle(Color.gazeTextMuted)
                                Spacer()
                                Image(systemName: vm.showBrandSection ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.gazeTextMuted)
                            }
                        }
                        .buttonStyle(.plain)

                        if vm.showBrandSection {
                            VStack(spacing: 10) {
                                if !vm.brands.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(vm.brands, id: \.self) { brand in
                                                HStack(spacing: 6) {
                                                    Text(brand)
                                                        .font(GazeType.labelLarge)
                                                        .foregroundStyle(Color.gazeTextPrimary)
                                                    Button { vm.removeBrand(brand) } label: {
                                                        Image(systemName: "xmark")
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundStyle(Color.gazeTextMuted)
                                                    }
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(
                                                    Capsule().fill(Color.gazeCard)
                                                        .overlay(Capsule().strokeBorder(Color.gazeBorder, lineWidth: 1))
                                                )
                                            }
                                        }
                                    }
                                }

                                if vm.brands.count < 5 {
                                    HStack(spacing: 10) {
                                        TextField("", text: $vm.newBrand,
                                                  prompt: Text("Add brand…").foregroundStyle(Color.gazeTextMuted))
                                            .font(GazeType.bodyMedium)
                                            .foregroundStyle(Color.gazeTextPrimary)
                                            .focused($brandFocused)
                                            .autocorrectionDisabled()
                                            .onSubmit { vm.addBrand() }

                                        Button(action: vm.addBrand) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(Color.gazeAccent)
                                        }
                                        .opacity(vm.newBrand.isEmpty ? 0.4 : 1.0)
                                    }
                                    .padding(14)
                                    .background(Color.gazeCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                brandFocused ? Color.gazeAccent.opacity(0.4) : Color.gazeBorder,
                                                lineWidth: 1
                                            )
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 28)

                // Continue to preview
                GazeButton(
                    label: "Preview post",
                    icon: "eye.fill",
                    style: (vm.caption.trimmingCharacters(in: .whitespaces).isEmpty || !vm.canPost)
                        ? .ghost : .primary
                ) {
                    captionFocused = false
                    brandFocused = false
                    linkFocused = false
                    withAnimation(GazeAnimations.spring) { vm.step = .preview }
                }
                .disabled(vm.caption.trimmingCharacters(in: .whitespaces).isEmpty || !vm.canPost)
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
            }
        }
        .background(Color.gazeBackground.ignoresSafeArea())
    }
}

// MARK: - Preview Step

private struct PostPreviewView: View {

    @ObservedObject var vm: PostViewModel
    @EnvironmentObject private var appVM: AppViewModel
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 88)

                // Label
                Text("This is how your post will look")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.gazeTextMuted)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.gazeCard)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(Color.gazeBorder),
                        alignment: .bottom
                    )

                // ── Post card replica ──────────────────────────────────────
                VStack(spacing: 0) {

                    // Header: avatar + name + timestamp
                    HStack(spacing: 12) {
                        GazeAvatar(user: appVM.currentUser, size: 36)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("@\(appVM.currentUser.username)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.gazeTextPrimary)
                            Text("Just now")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.gazeTextMuted)
                        }

                        Spacer()

                        // Visibility badge
                        HStack(spacing: 4) {
                            Image(systemName: vm.selectedVisibility == .friends
                                  ? "person.2.fill" : "globe")
                                .font(.system(size: 10))
                            Text(vm.selectedVisibility == .friends ? "Friends" : "Everyone")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Color.gazeTextMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(Color.gazeCard)
                                .overlay(Capsule().strokeBorder(Color.gazeBorder, lineWidth: 1))
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Image / gradient
                    Group {
                        if let img = vm.selectedImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                        } else {
                            OutfitGradientCard(
                                gradientIndex: vm.capturedGradientIndex,
                                cornerRadius: 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .background(Color.gazeBackground)
                    .clipped()

                    // Action row (non-interactive — preview only)
                    HStack(spacing: 20) {
                        HStack(spacing: 5) {
                            Image(systemName: "flame")
                                .font(.system(size: 20))
                            Text("0")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        HStack(spacing: 5) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 20))
                            Text("0")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Spacer()
                        Image(systemName: "bookmark")
                            .font(.system(size: 20))
                    }
                    .foregroundStyle(Color.gazeTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Caption
                    if !vm.caption.trimmingCharacters(in: .whitespaces).isEmpty {
                        HStack(alignment: .top, spacing: 0) {
                            Text("@\(appVM.currentUser.username) ")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.gazeTextPrimary)
                            + Text(vm.caption)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.gazeTextPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }

                    if let linkStr = SupabaseService.normalizedOutfitLinkForStorage(vm.productLink) {
                        HStack(spacing: 8) {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.gazeAccent)
                            Text(linkStr)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.gazeTextSecondary)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }

                    // Brand tags
                    if !vm.brands.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(vm.brands, id: \.self) { brand in
                                    Text(brand)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.gazeTextSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule().fill(Color.gazeCard)
                                                .overlay(Capsule().strokeBorder(Color.gazeBorder, lineWidth: 1))
                                        )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 12)
                    }
                }
                .background(Color.gazeCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.gazeBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                // Hint
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Tap back to make changes")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.gazeTextMuted)
                .padding(.top, 18)
                .opacity(appeared ? 1 : 0)

                // Post button
                GazeButton(label: "Post it", icon: "paperplane.fill") {
                    vm.publish(currentUser: appVM.currentUser)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 52)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(GazeAnimations.spring.delay(0.15), value: appeared)
            }
        }
        .background(Color.gazeBackground.ignoresSafeArea())
        .onAppear { withAnimation(GazeAnimations.spring) { appeared = true } }
    }
}

// MARK: - Publishing Step

private struct PostPublishingView: View {
    let progress: Double
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.gazeBorder, lineWidth: 3)
                        .frame(width: 96, height: 96)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.gazeAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))
                        .animation(GazeAnimations.standard, value: progress)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.gazeAccent)
                }

                VStack(spacing: 6) {
                    Text("Publishing…")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.gazeTextPrimary)
                    Text("\(Int(progress * 100))% uploaded")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.gazeTextSecondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gazeBackground.ignoresSafeArea())
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear { withAnimation(GazeAnimations.standard) { appeared = true } }
    }
}

// MARK: - Success Step

private struct PostSuccessView: View {
    let outfit: Outfit?
    let image: UIImage?
    let onDone: () -> Void

    @State private var appeared = false
    @State private var checkScale: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.gazeSuccess.opacity(0.1))
                        .frame(width: 110, height: 110)
                        .blur(radius: 16)

                    ZStack {
                        Circle()
                            .fill(Color.gazeSuccess.opacity(0.18))
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(Color.gazeSuccess)
                    }
                    .scaleEffect(checkScale)
                }

                VStack(spacing: 10) {
                    Text("You're live.")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(Color.gazeTextPrimary)
                    Text("Your outfit is out there.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.gazeTextSecondary)
                }

                if let outfit {
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let img = image {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                OutfitGradientCard(gradientIndex: outfit.gradientIndex, cornerRadius: 0)
                            }
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 32)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(outfit.caption)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                        .padding(14)
                        .padding(.horizontal, 32)
                    }
                }
            }
            .opacity(appeared ? 1.0 : 0.0)

            Spacer()

            GazeButton(label: "Back to feed", icon: "house.fill") { onDone() }
                .padding(.horizontal, 24)
                .padding(.bottom, 56)
                .opacity(appeared ? 1.0 : 0.0)
                .offset(y: appeared ? 0 : 20)
                .animation(GazeAnimations.spring.delay(0.3), value: appeared)
        }
        .background(Color.gazeBackground.ignoresSafeArea())
        .onAppear {
            withAnimation(GazeAnimations.spring) { appeared = true }
            withAnimation(GazeAnimations.springBouncy.delay(0.2)) { checkScale = 1.0 }
        }
    }
}
