import Testing
import Foundation
@testable import LensCore

@Suite("NormalizationService")
struct NormalizationServiceTests {
    let service = NormalizationService()

    @Test("verb produces 'to' + lemma")
    func verbNormalization() {
        let result = service.makePrimary(raw: "running", lemma: "run", pos: .verb)
        #expect(result == "to run")
    }

    @Test("adjective produces 'to be' + lemma")
    func adjectiveNormalization() {
        let result = service.makePrimary(raw: "efficient", lemma: "efficient", pos: .adjective)
        #expect(result == "to be efficient")
    }

    @Test("noun without article returns lemma")
    func nounNoArticle() {
        let result = service.makePrimary(raw: "Dogs", lemma: "dog", pos: .noun)
        #expect(result == "dog")
    }

    @Test("noun with article adds 'a'")
    func nounWithArticleA() {
        let result = service.makePrimary(raw: "Dog", lemma: "dog", pos: .noun, articleMode: true)
        #expect(result == "a dog")
    }

    @Test("noun with article adds 'an' for vowel")
    func nounWithArticleAn() {
        let result = service.makePrimary(raw: "Apple", lemma: "apple", pos: .noun, articleMode: true)
        #expect(result == "an apple")
    }

    @Test("phrase returns lowercased text")
    func phraseNormalization() {
        let result = service.makePrimary(
            raw: "In", lemma: "in", pos: .phrase,
            phraseText: "In terms of"
        )
        #expect(result == "in terms of")
    }

    @Test("verb with phrase text uses phrase")
    func verbPhrasal() {
        let result = service.makePrimary(
            raw: "carried", lemma: "carry", pos: .verb,
            phraseText: "carry out"
        )
        #expect(result == "to carry out")
    }

    @Test("comparison form normalizes to base adjective")
    func comparisonForm() {
        let result = service.makePrimary(
            raw: "more efficient", lemma: "efficient", pos: .adjective
        )
        #expect(result == "to be efficient")
    }

    @Test("article chooser selects correctly")
    func articleChooser() {
        #expect(NormalizationService.chooseArticle(for: "umbrella") == "an")
        #expect(NormalizationService.chooseArticle(for: "book") == "a")
        #expect(NormalizationService.chooseArticle(for: "elephant") == "an")
        #expect(NormalizationService.chooseArticle(for: "Car") == "a")
    }
}
