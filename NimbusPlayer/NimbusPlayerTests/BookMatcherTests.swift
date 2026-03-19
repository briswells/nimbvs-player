import Testing
@testable import NimbusPlayer

@Suite("BookMatcher Tests")
struct BookMatcherTests {

    // MARK: - Normalize Tests

    @Test func normalizeStripsSubtitleColon() {
        let result = BookMatcher.normalize("Project Hail Mary: A Novel")
        #expect(result == "project hail mary")
    }

    @Test func normalizeStripsSubtitleDash() {
        let result = BookMatcher.normalize("Dune - The First Novel")
        #expect(result == "dune")
    }

    @Test func normalizeStripsArticles() {
        let martian = BookMatcher.normalize("The Martian")
        #expect(martian == "martian")

        let brief = BookMatcher.normalize("A Brief History of Time")
        #expect(brief == "brief history of time")
    }

    // MARK: - Matching Tests

    @Test func matchByASIN() {
        let a = BookMatcher.BookIdentity(
            asin: "B08G9PRS1K",
            isbn: nil,
            title: "Project Hail Mary",
            author: "Andy Weir"
        )
        let b = BookMatcher.BookIdentity(
            asin: "B08G9PRS1K",
            isbn: nil,
            title: "Completely Different Title",
            author: "Someone Else"
        )
        #expect(BookMatcher.areMatching(a, b) == true)
    }

    @Test func matchByISBN() {
        let a = BookMatcher.BookIdentity(
            asin: nil,
            isbn: "9780593135204",
            title: "Project Hail Mary",
            author: "Andy Weir"
        )
        let b = BookMatcher.BookIdentity(
            asin: nil,
            isbn: "9780593135204",
            title: "Completely Different Title",
            author: "Someone Else"
        )
        #expect(BookMatcher.areMatching(a, b) == true)
    }

    @Test func matchByFuzzyTitleAndAuthor() {
        let a = BookMatcher.BookIdentity(
            asin: nil,
            isbn: nil,
            title: "Project Hail Mary",
            author: "Andy Weir"
        )
        let b = BookMatcher.BookIdentity(
            asin: nil,
            isbn: nil,
            title: "Project Hail Mary: A Novel",
            author: "Andy Weir"
        )
        #expect(BookMatcher.areMatching(a, b) == true)
    }

    @Test func noMatchDifferentAuthorSameTitle() {
        let a = BookMatcher.BookIdentity(
            asin: nil,
            isbn: nil,
            title: "Dune",
            author: "Frank Herbert"
        )
        let b = BookMatcher.BookIdentity(
            asin: nil,
            isbn: nil,
            title: "Dune",
            author: "Kevin J. Anderson"
        )
        #expect(BookMatcher.areMatching(a, b) == false)
    }

    @Test func noMatchDifferentBooks() {
        let a = BookMatcher.BookIdentity(
            asin: nil,
            isbn: nil,
            title: "The Martian",
            author: "Andy Weir"
        )
        let b = BookMatcher.BookIdentity(
            asin: nil,
            isbn: nil,
            title: "Artemis",
            author: "Andy Weir"
        )
        #expect(BookMatcher.areMatching(a, b) == false)
    }
}
