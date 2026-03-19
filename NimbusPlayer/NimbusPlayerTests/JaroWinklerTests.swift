import Testing
@testable import NimbusPlayer

@Suite("JaroWinkler Similarity")
struct JaroWinklerTests {

    @Test func identicalStrings() {
        #expect(JaroWinkler.similarity("hello", "hello") == 1.0)
        #expect(JaroWinkler.similarity("audiobook", "audiobook") == 1.0)
    }

    @Test func completelyDifferent() {
        let score = JaroWinkler.similarity("abc", "xyz")
        #expect(score < 0.5)
    }

    @Test func similarStrings() {
        let score = JaroWinkler.similarity("martha", "marhta")
        #expect(score > 0.95)
    }

    @Test func emptyStrings() {
        #expect(JaroWinkler.similarity("", "") == 0.0)
        #expect(JaroWinkler.similarity("hello", "") == 0.0)
        #expect(JaroWinkler.similarity("", "hello") == 0.0)
    }

    @Test func caseInsensitive() {
        #expect(JaroWinkler.similarity("Hello", "hello") == 1.0)
        #expect(JaroWinkler.similarity("WORLD", "world") == 1.0)
        #expect(JaroWinkler.similarity("Swift", "swift") == 1.0)
    }

    @Test func bookTitleSimilarity() {
        let score = JaroWinkler.similarity("The Great Gatsby", "The Great Gatsby")
        #expect(score == 1.0)
    }

    @Test func slightlyDifferentTitles() {
        let score = JaroWinkler.similarity("the martian", "martian")
        #expect(score > 0.7)
    }
}
