import Foundation
import UIKit
import Supabase

private struct _DBComment: Decodable {
    let id: UUID
    let userId: UUID
    let body: String
    let createdAt: Date
    let profiles: DBProfile?
    enum CodingKeys: String, CodingKey {
        case id, body, profiles
        case userId    = "user_id"
        case createdAt = "created_at"
    }
}

// MARK: - Challenge Service

@MainActor
final class ChallengeService {

    static let shared = ChallengeService()
    private let sb = SupabaseManager.shared.client
    private init() {}

    // MARK: - Load

    func loadActiveChallenge() async throws -> ChallengeWeek? {
        try await sb
            .rpc("get_active_challenge_with_context")
            .execute()
            .value
    }

    func loadChallengeFeed(challengeId: UUID) async throws -> [ChallengeSubmission] {
        try await sb
            .rpc("get_challenge_feed",
                 params: ["p_challenge_id": challengeId.uuidString])
            .execute()
            .value
    }

    func loadFinalsFeed(challengeId: UUID) async throws -> [ChallengeSubmission] {
        try await sb
            .rpc("get_finals_feed",
                 params: ["p_challenge_id": challengeId.uuidString])
            .execute()
            .value
    }

    // MARK: - Submit flow

    func saveDraft(challengeId: UUID, imageUrl: String, caption: String?) async throws -> ChallengeWeek.MySubmission {
        var params: [String: String] = [
            "p_challenge_id": challengeId.uuidString,
            "p_image_url": imageUrl
        ]
        if let caption { params["p_caption"] = caption }
        return try await sb
            .rpc("upsert_draft_submission", params: params)
            .execute()
            .value
    }

    func confirmSubmission(submissionId: UUID) async throws -> ChallengeWeek.MySubmission {
        try await sb
            .rpc("confirm_submission",
                 params: ["p_submission_id": submissionId.uuidString])
            .execute()
            .value
    }

    // MARK: - Votes

    func voteOnSubmission(submissionId: UUID) async throws {
        try await sb
            .rpc("vote_on_submission",
                 params: ["p_submission_id": submissionId.uuidString])
            .execute()
    }

    func voteInFinals(challengeId: UUID, submissionId: UUID) async throws {
        try await sb
            .rpc("vote_in_finals",
                 params: [
                    "p_challenge_id": challengeId.uuidString,
                    "p_submission_id": submissionId.uuidString
                 ])
            .execute()
    }

    // MARK: - Likes

    func likeSubmission(submissionId: UUID, userId: UUID) async throws {
        try await sb.from("challenge_submission_likes")
            .upsert(
                ["submission_id": submissionId.uuidString, "user_id": userId.uuidString],
                onConflict: "submission_id,user_id",
                ignoreDuplicates: true
            )
            .execute()
    }

    func unlikeSubmission(submissionId: UUID, userId: UUID) async throws {
        try await sb.from("challenge_submission_likes")
            .delete()
            .eq("submission_id", value: submissionId)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Upload

    func uploadChallengePhoto(_ image: UIImage, userId: UUID) async throws -> String {
        let compressed = resized(image, maxWidth: 1200)
        guard let data = compressed.jpegData(compressionQuality: 0.82) else {
            throw GazeError.uploadFailed
        }
        let path = "challenge/\(userId.uuidString)/\(Int(Date().timeIntervalSince1970)).jpg"
        try await sb.storage
            .from("outfit-photos")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
        let url = try sb.storage.from("outfit-photos").getPublicURL(path: path)
        return url.absoluteString
    }

    // MARK: - Comments

    func loadComments(submissionId: UUID) async throws -> [ChallengeComment] {
        let rows: [_DBComment] = try await sb.from("challenge_submission_comments")
            .select("*, profiles(*)")
            .eq("submission_id", value: submissionId)
            .order("created_at", ascending: true)
            .limit(200)
            .execute()
            .value
        return rows.map {
            ChallengeComment(
                id: $0.id,
                userId: $0.userId,
                body: $0.body,
                createdAt: $0.createdAt,
                username: $0.profiles?.username,
                avatarUrl: $0.profiles?.avatarUrl
            )
        }
    }

    func addComment(submissionId: UUID, userId: UUID, body: String) async throws {
        try await sb.from("challenge_submission_comments")
            .insert([
                "submission_id": submissionId.uuidString,
                "user_id": userId.uuidString,
                "body": body
            ])
            .execute()
    }

    // MARK: - Private

    private func resized(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        guard image.size.width > maxWidth else { return image }
        let scale = maxWidth / image.size.width
        let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
