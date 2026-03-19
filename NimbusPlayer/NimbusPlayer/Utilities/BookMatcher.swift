import Foundation

enum BookMatcher {

    struct BookIdentity {
        let asin: String?
        let isbn: String?
        let title: String
        let author: String
    }

    static let similarityThreshold = 0.95

    static func areMatching(_ a: BookIdentity, _ b: BookIdentity) -> Bool {
        // 1. Exact ASIN match (if both non-empty)
        if let asinA = a.asin, !asinA.isEmpty,
           let asinB = b.asin, !asinB.isEmpty,
           asinA == asinB {
            return true
        }

        // 2. Exact ISBN match (if both non-empty)
        if let isbnA = a.isbn, !isbnA.isEmpty,
           let isbnB = b.isbn, !isbnB.isEmpty,
           isbnA == isbnB {
            return true
        }

        // 3. Fuzzy: both normalized title AND author must have JaroWinkler >= threshold
        let titleSimilarity = JaroWinkler.similarity(normalize(a.title), normalize(b.title))
        let authorSimilarity = JaroWinkler.similarity(normalize(a.author), normalize(b.author))
        return titleSimilarity >= similarityThreshold && authorSimilarity >= similarityThreshold
    }

    static func normalize(_ string: String) -> String {
        // Lowercase, trim whitespace
        var result = string.lowercased().trimmingCharacters(in: .whitespaces)

        // Strip subtitle after ":" or " - " (take first part)
        if let colonRange = result.range(of: ":") {
            result = String(result[result.startIndex..<colonRange.lowerBound])
        }
        if let dashRange = result.range(of: " - ") {
            result = String(result[result.startIndex..<dashRange.lowerBound])
        }

        // Remove leading articles: "the ", "a ", "an "
        let articles = ["the ", "a ", "an "]
        for article in articles {
            if result.hasPrefix(article) {
                result = String(result.dropFirst(article.count))
                break
            }
        }

        // Trim again
        result = result.trimmingCharacters(in: .whitespaces)

        return result
    }
}
