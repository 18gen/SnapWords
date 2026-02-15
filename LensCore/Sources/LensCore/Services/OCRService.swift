import UIKit
import Vision

public struct OCRService: Sendable {
    public init() {}

    /// Fast recognition from a CVPixelBuffer (for live camera frames). Uses `.fast` level.
    public func recognizeTokens(from pixelBuffer: CVPixelBuffer) async throws -> [RecognizedToken] {
        let imageWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let tokens = Self.buildTokens(from: observations, imageWidth: imageWidth, imageHeight: imageHeight)
                continuation.resume(returning: tokens)
            }
            request.recognitionLevel = .fast
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Accurate recognition from a UIImage. Uses `.accurate` level.
    public func recognizeTokens(from image: UIImage) async throws -> [RecognizedToken] {
        guard let cgImage = image.cgImage else {
            return []
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let tokens = Self.buildTokens(from: observations, imageWidth: imageWidth, imageHeight: imageHeight)
                continuation.resume(returning: tokens)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Shared Token Builder

    private static func buildTokens(
        from observations: [VNRecognizedTextObservation],
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> [RecognizedToken] {
        var lineGroups: [(yCenter: CGFloat, observations: [(VNRecognizedTextObservation, String, Float)])] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let confidence = candidate.confidence
            let box = observation.boundingBox
            let yCenter = box.origin.y + box.height / 2.0

            var assigned = false
            for i in lineGroups.indices {
                if abs(lineGroups[i].yCenter - yCenter) < 0.015 {
                    lineGroups[i].observations.append((observation, text, confidence))
                    lineGroups[i].yCenter = (lineGroups[i].yCenter + yCenter) / 2.0
                    assigned = true
                    break
                }
            }
            if !assigned {
                lineGroups.append((yCenter: yCenter, observations: [(observation, text, confidence)]))
            }
        }

        lineGroups.sort { $0.yCenter > $1.yCenter }

        var tokens: [RecognizedToken] = []
        for (lineId, group) in lineGroups.enumerated() {
            let sortedObs = group.observations.sorted { $0.0.boundingBox.origin.x < $1.0.boundingBox.origin.x }

            for (observation, fullText, confidence) in sortedObs {
                let words = fullText.split(separator: " ")
                if words.count <= 1 {
                    let cleaned = cleanWord(fullText)
                    guard !cleaned.isEmpty,
                          cleaned.rangeOfCharacter(from: .letters) != nil else { continue }

                    let box = observation.boundingBox
                    let imageRect = CGRect(
                        x: box.origin.x * imageWidth,
                        y: (1.0 - box.origin.y - box.height) * imageHeight,
                        width: box.width * imageWidth,
                        height: box.height * imageHeight
                    )
                    tokens.append(RecognizedToken(
                        text: cleaned,
                        normalizedText: cleaned.lowercased()
                            .trimmingCharacters(in: .punctuationCharacters),
                        boundingBox: imageRect,
                        lineId: lineId,
                        confidence: confidence
                    ))
                } else {
                    let boxWidth = observation.boundingBox.width
                    let totalCharCount = fullText.count
                    let boxOriginX = observation.boundingBox.origin.x
                    let boxOriginY = observation.boundingBox.origin.y
                    let boxHeight = observation.boundingBox.height

                    var charOffset = 0
                    for word in words {
                        let wordStr = String(word)
                        let cleaned = cleanWord(wordStr)

                        // Advance char offset regardless of whether we keep the token
                        defer { charOffset += wordStr.count + 1 }

                        guard !cleaned.isEmpty,
                              cleaned.rangeOfCharacter(from: .letters) != nil else { continue }

                        let startFraction = CGFloat(charOffset) / CGFloat(totalCharCount)
                        let widthFraction = CGFloat(wordStr.count) / CGFloat(totalCharCount)

                        let visionRect = CGRect(
                            x: boxOriginX + boxWidth * startFraction,
                            y: boxOriginY,
                            width: boxWidth * widthFraction,
                            height: boxHeight
                        )
                        let imageRect = CGRect(
                            x: visionRect.origin.x * imageWidth,
                            y: (1.0 - visionRect.origin.y - visionRect.height) * imageHeight,
                            width: visionRect.width * imageWidth,
                            height: visionRect.height * imageHeight
                        )

                        tokens.append(RecognizedToken(
                            text: cleaned,
                            normalizedText: cleaned.lowercased()
                                .trimmingCharacters(in: .punctuationCharacters),
                            boundingBox: imageRect,
                            lineId: lineId,
                            confidence: confidence
                        ))
                    }
                }
            }
        }

        return tokens
    }

    /// Strip leading/trailing punctuation and symbols from a word.
    private static func cleanWord(_ raw: String) -> String {
        let trimSet = CharacterSet.letters.union(.decimalDigits).inverted
        return raw.trimmingCharacters(in: trimSet)
    }
}
