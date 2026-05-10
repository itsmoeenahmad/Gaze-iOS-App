import Foundation
import UIKit
import Supabase

// MARK: - Storage Service (photo upload to Supabase Storage)

final class StorageService {

    static let shared = StorageService()
    private let sb = SupabaseManager.shared.client
    private let bucket = "outfit-photos"

    private init() {}

    /// Upload an outfit photo and return its public URL string.
    func uploadOutfitPhoto(image: UIImage, userId: UUID) async throws -> String {
        let compressed = resized(image, maxWidth: 1200)
        guard let data = compressed.jpegData(compressionQuality: 0.82) else {
            throw GazeError.uploadFailed
        }
        let path = "\(userId.uuidString)/\(Int(Date().timeIntervalSince1970)).jpg"
        try await sb.storage
            .from(bucket)
            .upload(path, data: data,
                    options: FileOptions(contentType: "image/jpeg"))
        let url = try sb.storage.from(bucket).getPublicURL(path: path)
        return url.absoluteString
    }

    /// Upload an avatar photo and return its public URL string.
    func uploadAvatar(image: UIImage, userId: UUID) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw GazeError.uploadFailed
        }
        let path = "avatars/\(userId.uuidString).jpg"
        try await sb.storage
            .from(bucket)
            .upload(path, data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: true))
        let url = try sb.storage.from(bucket).getPublicURL(path: path)
        return url.absoluteString
    }

    // MARK: - Helpers

    private func resized(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        guard image.size.width > maxWidth else { return image }
        let scale = maxWidth / image.size.width
        let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
