import Foundation

// MARK: - AI Query Expansion Result

struct AIQueryExpansion {
    let categories: [StyleCategory]
    let keywords: [String]
    let matchAll: Bool
}

// MARK: - AI Search Service (Claude-powered)

final class AISearchService {

    static let shared = AISearchService()

    /// In production, AI search should be proxied through a Supabase Edge Function
    /// to avoid exposing API keys in the client bundle.
    private(set) var apiKey: String = ""

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private init() {
        // Never read a client-bundled Anthropic key in Release — it would be extractable from the binary.
        #if DEBUG
        if let key = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String,
           !key.isEmpty {
            apiKey = key
            AppLogger.warning("ANTHROPIC_API_KEY is set in the app bundle — DEBUG only; use an Edge Function proxy for production", category: .api)
        }
        #else
        apiKey = ""
        #endif
    }

    func expandQuery(_ query: String) async -> AIQueryExpansion {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return AIQueryExpansion(categories: [], keywords: [], matchAll: true)
        }

        if !apiKey.isEmpty {
            if let result = try? await callClaude(query: query) {
                return result
            }
        }

        return fallbackExpansion(for: query)
    }

    // MARK: - Claude API Call

    private func callClaude(query: String) async throws -> AIQueryExpansion {
        let prompt = """
        You are a fashion outfit search assistant. Given the user's search query "\(query)", determine what kind of outfits they're looking for.

        Return ONLY a valid JSON object, no other text:
        {
          "categories": [matching categories from ONLY this list: Streetwear, Quiet Luxury, Monochrome, Summer, Minimalist, Vintage, Athleisure, Formal, Techwear, Grunge],
          "keywords": [up to 8 words likely to appear in outfit captions or brand names],
          "matchAll": false
        }

        Examples:
        - "old money" → categories: ["Quiet Luxury","Minimalist","Formal"], keywords: ["blazer","polo","loafer","navy","beige","cashmere","preppy","oxford"]
        - "women" → categories: [], keywords: ["women","girl","feminine","her","she"], matchAll: false
        - "athletic" → categories: ["Athleisure"], keywords: ["nike","adidas","gym","sport","workout","running","sneaker","track"]
        - "dark" → categories: ["Grunge","Techwear","Monochrome"], keywords: ["black","dark","shadow","leather","matte","gothic"]
        - "summer vibes" → categories: ["Summer"], keywords: ["beach","tan","linen","shorts","sandal","floral","tropical","vacation"]

        Set "matchAll" to true only if the query is extremely generic like "outfit", "fashion", "clothes".
        """

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 200,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct ClaudeResponse: Decodable {
            struct Content: Decodable { let text: String }
            let content: [Content]
        }
        struct Expansion: Decodable {
            let categories: [String]
            let keywords: [String]
            let matchAll: Bool
        }

        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = response.content.first?.text,
              let jsonData = text.data(using: .utf8),
              let expansion = try? JSONDecoder().decode(Expansion.self, from: jsonData)
        else { return fallbackExpansion(for: query) }

        let mapped = expansion.categories.compactMap { StyleCategory(rawValue: $0) }
        return AIQueryExpansion(categories: mapped, keywords: expansion.keywords, matchAll: expansion.matchAll)
    }

    // MARK: - Fallback (no API key)

    private func fallbackExpansion(for query: String) -> AIQueryExpansion {
        let q = query.lowercased()
        var cats: [StyleCategory] = []

        let rules: [(String, StyleCategory)] = [
            ("street|urban|hype|skate|hip hop|drill", .streetwear),
            ("luxury|old money|preppy|bougie|rich|wealth|classy", .quietLuxury),
            ("minimal|clean|simple|basic|neutral|nude", .minimalist),
            ("vintage|retro|thrift|80s|90s|70s|classic|antique", .vintage),
            ("sport|athletic|gym|workout|running|fit|yoga|active", .athleisure),
            ("formal|suit|business|office|professional|smart", .formal),
            ("summer|beach|tropical|vacation|holiday|sun|warm", .summer),
            ("tech|cyber|future|matrix|ninja|tactical|utility", .techwear),
            ("grunge|punk|dark|goth|rock|emo|edge", .grunge),
            ("mono|black|white|grey|gray|tone", .monochrome),
        ]

        for (pattern, category) in rules {
            if q.range(of: pattern, options: .regularExpression) != nil {
                cats.append(category)
            }
        }

        return AIQueryExpansion(categories: cats, keywords: [query], matchAll: cats.isEmpty && q.count < 3)
    }
}
