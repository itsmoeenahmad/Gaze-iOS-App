import SwiftUI
import Combine

// MARK: - Post Step

enum PostStep {
    case camera
    case compose
    case preview
    case publishing
    case success
}

// MARK: - Post ViewModel

@MainActor
final class PostViewModel: ObservableObject {

    @Published var step: PostStep = .camera
    @Published var capturedGradientIndex: Int = 0
    @Published var selectedImage: UIImage? = nil
    @Published var caption: String = ""
    @Published var brands: [String] = []
    @Published var newBrand: String = ""
    @Published var selectedCategory: StyleCategory = .streetwear
    @Published var selectedPriceLevel: PriceLevel = .mid
    @Published var selectedVisibility: PostVisibility = .friends
    @Published var isCapturing: Bool = false
    @Published var publishProgress: Double = 0.0
    @Published var publishedOutfit: Outfit? = nil
    @Published var dailyPostCount: Int = 0
    @Published var showBrandSection: Bool = true
    @Published var publishError: String? = nil
    /// Raw user input; stored on `outfits.link` after trim + https normalization.
    @Published var productLink: String = ""

    var canPost: Bool { dailyPostCount < 2 }

    init() {
        // Immediately verify against DB — authoritative across all devices and reinstalls
        Task { await loadDailyCount() }
    }

    func loadDailyCount() async {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        let count = (try? await SupabaseService.shared.fetchTodayPostCount(userId: userId)) ?? 0
        dailyPostCount = count
    }

    func capturePhoto() {
        GazeHaptics.heavy()
        isCapturing = true
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            isCapturing = false
            capturedGradientIndex = Int.random(in: 0..<GazeGradients.outfitPalettes.count)
            withAnimation(GazeAnimations.spring) {
                step = .compose
            }
        }
    }

    func retake() {
        withAnimation(GazeAnimations.spring) {
            step = .camera
            caption = ""
            brands = []
            newBrand = ""
            productLink = ""
        }
    }

    func addBrand() {
        let trimmed = newBrand.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !brands.contains(trimmed), brands.count < 5 else { return }
        GazeHaptics.light()
        withAnimation(GazeAnimations.spring) {
            brands.append(trimmed)
            newBrand = ""
        }
    }

    func removeBrand(_ brand: String) {
        GazeHaptics.light()
        withAnimation(GazeAnimations.spring) {
            brands.removeAll { $0 == brand }
        }
    }

    func publish(currentUser: GazeUser) {
        guard !caption.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard canPost else { return }
        GazeHaptics.medium()
        AppLogger.info("Publish started", category: .post, properties: ["user_id": currentUser.id.uuidString, "has_image": "\(selectedImage != nil)", "visibility": selectedVisibility.rawValue])

        withAnimation(GazeAnimations.standard) { step = .publishing }

        Task {
            await loadDailyCount()
            guard canPost else {
                AppLogger.warning("Publish blocked — daily limit reached", category: .post, properties: ["daily_count": "\(dailyPostCount)"])
                withAnimation(GazeAnimations.spring) { step = .compose }
                publishError = "You've reached your 2 post limit for today."
                return
            }

            var imageURL: String? = nil
            if let image = selectedImage {
                withAnimation(.easeInOut(duration: 0.15)) { publishProgress = 0.1 }
                do {
                    imageURL = try await StorageService.shared.uploadOutfitPhoto(
                        image: image, userId: currentUser.id)
                    AppLogger.info("Photo uploaded", category: .post)
                } catch {
                    AppLogger.warning("Photo upload failed, continuing with gradient", category: .post, properties: ["error": error.localizedDescription])
                }
                withAnimation(.easeInOut(duration: 0.15)) { publishProgress = 0.5 }
            } else {
                withAnimation(.easeInOut(duration: 0.15)) { publishProgress = 0.5 }
            }

            let outfit: Outfit
            do {
                var inserted = try await SupabaseService.shared.insertOutfit(
                    userId: currentUser.id,
                    gradientIndex: capturedGradientIndex,
                    imageUrl: imageURL,
                    caption: caption,
                    brands: brands,
                    category: selectedCategory,
                    priceLevel: selectedPriceLevel,
                    city: currentUser.city,
                    visibility: selectedVisibility,
                    productLink: productLink
                )
                inserted.user = currentUser
                outfit = inserted
            } catch {
                publishProgress = 0
                publishError = "Failed to post. Check your connection and try again."
                AppLogger.error("Publish failed — DB insert error", category: .post, properties: ["error": error.localizedDescription])
                withAnimation(GazeAnimations.spring) { step = .compose }
                return
            }

            withAnimation(.easeInOut(duration: 0.15)) { publishProgress = 0.9 }

            publishedOutfit = outfit
            dailyPostCount += 1
            if let image = selectedImage {
                MockDataService.shared.saveImageLocally(image, outfitId: outfit.id)
            }
            NotificationCenter.default.post(name: .gazeNewPost, object: outfit)
            AppLogger.info("Post published successfully", category: .post, properties: ["outfit_id": outfit.id.uuidString, "daily_count": "\(dailyPostCount)"])

            withAnimation(.easeInOut(duration: 0.15)) { publishProgress = 1.0 }
            try? await Task.sleep(nanoseconds: 200_000_000)
            GazeHaptics.success()
            withAnimation(GazeAnimations.spring) { step = .success }
        }
    }

    func reset() {
        step = .camera
        caption = ""
        brands = []
        newBrand = ""
        publishProgress = 0
        publishedOutfit = nil
        publishError = nil
        capturedGradientIndex = 0
        selectedImage = nil
        showBrandSection = false
        productLink = ""
        // dailyPostCount is server-authoritative — reloaded on next init
    }
}
