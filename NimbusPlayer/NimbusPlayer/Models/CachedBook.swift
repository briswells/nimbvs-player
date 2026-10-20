import Foundation
import SwiftData

// MARK: - CachedBook

/// A locally cached audiobook that may exist on one or more servers.
///
/// The book's `id` is deterministic via `UUIDv5.bookID`, ensuring the same
/// book from different servers resolves to a single `CachedBook` record.
@Model
final class CachedBook {

    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var narrator: String?
    var asin: String?
    var isbn: String?
    var bookDescription: String?
    var duration: TimeInterval
    var coverPath: String?
    var seriesName: String?
    var seriesSequence: String?
    var seriesId: String?
    var genres: [String] = []
    var lastUpdated: Date

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \ServerBookMapping.book)
    var serverMappings: [ServerBookMapping] = []

    @Relationship(deleteRule: .cascade)
    var progress: ListeningProgress?

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.book)
    var bookmarks: [Bookmark] = []

    @Relationship(deleteRule: .cascade, inverse: \DownloadModel.book)
    var downloads: [DownloadModel] = []

    // MARK: - Init

    init(
        title: String,
        author: String,
        duration: TimeInterval,
        asin: String? = nil,
        isbn: String? = nil,
        narrator: String? = nil,
        bookDescription: String? = nil,
        coverPath: String? = nil,
        seriesName: String? = nil,
        seriesSequence: String? = nil
    ) {
        self.id = UUIDv5.bookID(asin: asin, isbn: isbn, title: title, author: author)
        self.title = title
        self.author = author
        self.narrator = narrator
        self.asin = asin
        self.isbn = isbn
        self.bookDescription = bookDescription
        self.duration = duration
        self.coverPath = coverPath
        self.seriesName = seriesName
        self.seriesSequence = seriesSequence
        self.lastUpdated = Date()
    }

    // MARK: - Computed

    /// The preferred server mapping, or the first available mapping if none is marked preferred.
    var preferredMapping: ServerBookMapping? {
        serverMappings.first(where: { $0.isPreferred }) ?? serverMappings.first
    }

    /// Whether this book is available on more than one server.
    var isMultiServer: Bool {
        serverMappings.count > 1
    }
}

// MARK: - Description Text

extension CachedBook {

    /// `bookDescription` as display-ready plain text, or nil if it's empty.
    ///
    /// Audiobookshelf passes descriptions through from its metadata providers, often as HTML
    /// (`<br />`, `<p>`, entities), which `Text` would otherwise show literally.
    var plainDescription: String? {
        guard let bookDescription else { return nil }
        let text = Self.plainText(fromHTML: bookDescription)
        return text.isEmpty ? nil : text
    }

    /// Converts simple HTML to plain text: line breaks and paragraphs become newlines, list items
    /// become bullets, other tags are dropped, and entities are decoded (once).
    static func plainText(fromHTML html: String) -> String {
        func replace(_ pattern: String, _ template: String, in text: String) -> String {
            text.replacingOccurrences(of: pattern, with: template, options: [.regularExpression, .caseInsensitive])
        }

        var text = html
        text = replace(#"<br\s*/?>"#, "\n", in: text)
        text = replace(#"</(p|div|h[1-6]|ul|ol)\s*>"#, "\n\n", in: text)
        text = replace(#"<li\b[^>]*>"#, "\n• ", in: text)
        text = replace(#"<[a-z/!][^>]*>"#, "", in: text)
        text = decodeEntities(text)
        text = replace(#"[ \t]+\n"#, "\n", in: text)
        text = replace(#"\n[ \t]+"#, "\n", in: text)
        text = replace(#"\n{3,}"#, "\n\n", in: text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "mdash": "—", "ndash": "–", "hellip": "…", "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“"
    ]

    /// Decodes named and numeric entities in a single pass, so `&amp;lt;` becomes `&lt;`, not `<`.
    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&"),
              let regex = try? NSRegularExpression(pattern: "&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);") else { return text }

        var result = ""
        var cursor = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text), let body = Range(match.range(at: 1), in: text) else { continue }
            result += text[cursor..<whole.lowerBound]
            let name = String(text[body])
            let scalar: Unicode.Scalar? = name.hasPrefix("#x") || name.hasPrefix("#X")
                ? UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init)
                : name.hasPrefix("#") ? UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init) : nil
            if let scalar {
                result.unicodeScalars.append(scalar)
            } else if let named = namedEntities[name.lowercased()] {
                result += named
            } else {
                result += text[whole]
            }
            cursor = whole.upperBound
        }
        result += text[cursor...]
        return result
    }
}
