import Foundation
import UIKit

public struct GroqRichResult: Sendable {
    public let translation: String
    public let definition: String
    public let example: String
    public let pos: POS
    public let lemma: String
    public let phrase: String?
}

public enum GroqError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case noContent
}

public struct GroqService: Sendable {
    public init() {}

    // MARK: - Vision analysis (primary)

    public func analyzeWithVision(
        word: String,
        imageCrop: UIImage,
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> GroqRichResult {
        let sourceName = languageName(for: sourceLanguage)
        let targetName = languageName(for: targetLanguage)

        let resized = resizedForVision(imageCrop, maxWidth: 1024)
        let base64 = base64Encode(resized, quality: 0.8)

        let systemPrompt = richSystemPrompt(
            sourceName: sourceName, targetName: targetName, word: word
        )

        let userContent: [[String: Any]] = [
            ["type": "text", "text": "User tapped the word: \"\(word)\""],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
        ]

        let body: [String: Any] = [
            "model": "llama-3.2-90b-vision-preview",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "temperature": 0.0,
            "max_tokens": 300
        ]

        var request = makeRequest()
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await execute(request)
    }

    // MARK: - Text analysis (fallback)

    public func analyzeWithText(
        word: String,
        context: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> GroqRichResult {
        let sourceName = languageName(for: sourceLanguage)
        let targetName = languageName(for: targetLanguage)

        let systemPrompt = richSystemPrompt(
            sourceName: sourceName, targetName: targetName, word: word
        )

        let userMessage = "User tapped the word: \"\(word)\"\nContext:\n\(context)"

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.0,
            "max_tokens": 300
        ]

        var request = makeRequest()
        request.timeoutInterval = 10
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await execute(request)
    }

    // MARK: - Shared prompt

    private func richSystemPrompt(
        sourceName: String, targetName: String, word: String
    ) -> String {
        """
        You are a vocabulary assistant. The user tapped the \(sourceName) word "\(word)" in text they are reading.

        Analyze this word IN ITS SPECIFIC CONTEXT. Return a JSON object:
        - "translation": the \(targetName) translation appropriate for this context
        - "definition": 1-sentence explanation in simple \(sourceName) of this specific meaning/nuance
        - "example": example sentence in \(sourceName) using the word with this same meaning
        - "pos": one of "verb", "adjective", "noun", "phrase", "other"
        - "lemma": base/dictionary form in \(sourceName)
        - "phrase": if the word is part of a multi-word expression (phrasal verb, idiom), the full phrase; otherwise null

        IMPORTANT: Detect phrases. e.g. "take" in "take off your shoes" → phrase: "take off"
        Respond with only the JSON object.
        """
    }

    // MARK: - Network helpers

    private func makeRequest() -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.groqAPIKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func execute(_ request: URLRequest) async throws -> GroqRichResult {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw GroqError.httpError(statusCode: http.statusCode)
        }

        guard let outer = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = outer["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.noContent
        }

        let cleaned = stripMarkdownCodeBlock(content)

        guard let contentData = cleaned.data(using: .utf8) else {
            throw GroqError.decodingError
        }

        let parsed = try JSONDecoder().decode(GroqResponseContent.self, from: contentData)

        return GroqRichResult(
            translation: parsed.translation,
            definition: parsed.definition ?? "",
            example: parsed.example ?? "",
            pos: POS(rawValue: parsed.pos) ?? .other,
            lemma: parsed.lemma,
            phrase: parsed.phrase
        )
    }

    // MARK: - Image helpers

    private func resizedForVision(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxWidth else { return image }
        let scale = maxWidth / size.width
        let newSize = CGSize(width: maxWidth, height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func base64Encode(_ image: UIImage, quality: CGFloat) -> String {
        image.jpegData(compressionQuality: quality)?.base64EncodedString() ?? ""
    }

    /// Strip ```json ... ``` wrappers that vision models sometimes add.
    private func stripMarkdownCodeBlock(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            // Remove opening line (```json or ```)
            if let end = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: end)...])
            }
            // Remove closing ```
            if s.hasSuffix("```") {
                s = String(s.dropLast(3))
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }

    private func languageName(for code: String) -> String {
        switch code {
        case "ja": return "Japanese"
        case "en": return "English"
        default: return code
        }
    }
}

private struct GroqResponseContent: Decodable {
    let translation: String
    let definition: String?
    let example: String?
    let pos: String
    let lemma: String
    let phrase: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        translation = try container.decode(String.self, forKey: .translation)
        definition = try container.decodeIfPresent(String.self, forKey: .definition)
        example = try container.decodeIfPresent(String.self, forKey: .example)
        pos = try container.decode(String.self, forKey: .pos)
        lemma = try container.decode(String.self, forKey: .lemma)
        phrase = try container.decodeIfPresent(String.self, forKey: .phrase)
    }

    enum CodingKeys: String, CodingKey {
        case translation, definition, example, pos, lemma, phrase
    }
}
