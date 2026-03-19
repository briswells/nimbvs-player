import Testing
@testable import NimbusPlayer

@Suite("UUIDv5")
struct UUIDv5Tests {

    @Test func sameInputProducesSameUUID() {
        let uuid1 = UUIDv5.generate(namespace: UUIDv5.nimbusNamespace, name: "test-input")
        let uuid2 = UUIDv5.generate(namespace: UUIDv5.nimbusNamespace, name: "test-input")
        #expect(uuid1 == uuid2)
    }

    @Test func differentInputProducesDifferentUUID() {
        let uuid1 = UUIDv5.generate(namespace: UUIDv5.nimbusNamespace, name: "input-one")
        let uuid2 = UUIDv5.generate(namespace: UUIDv5.nimbusNamespace, name: "input-two")
        #expect(uuid1 != uuid2)
    }

    @Test func versionAndVariantBitsCorrect() {
        let uuid = UUIDv5.generate(namespace: UUIDv5.nimbusNamespace, name: "version-check")
        let uuidString = uuid.uuidString  // Uppercased, format: 8-4-4-4-12

        // Character at index 14 should be "5" (version nibble)
        let versionIndex = uuidString.index(uuidString.startIndex, offsetBy: 14)
        #expect(uuidString[versionIndex] == "5")

        // Character at index 19 should be in "89AB" (variant bits)
        let variantIndex = uuidString.index(uuidString.startIndex, offsetBy: 19)
        let variantChar = uuidString[variantIndex]
        #expect("89AB".contains(variantChar))
    }

    @Test func emptyNameProducesValidUUID() {
        let uuid = UUIDv5.generate(namespace: UUIDv5.nimbusNamespace, name: "")
        let uuidString = uuid.uuidString
        // Should still produce a valid UUID (36 chars with hyphens)
        #expect(uuidString.count == 36)
        // Version and variant should still be correct
        let versionIndex = uuidString.index(uuidString.startIndex, offsetBy: 14)
        #expect(uuidString[versionIndex] == "5")
        let variantIndex = uuidString.index(uuidString.startIndex, offsetBy: 19)
        #expect("89AB".contains(uuidString[variantIndex]))
    }

    @Test func bookIDUsesASINWhenAvailable() {
        let uuid1 = UUIDv5.bookID(asin: "B08G9PRS1K", isbn: "978-0-13-468599-1", title: "Title", author: "Author")
        let uuid2 = UUIDv5.bookID(asin: "B08G9PRS1K", isbn: nil, title: nil, author: nil)
        #expect(uuid1 == uuid2)
    }

    @Test func bookIDUsesISBNWhenNoASIN() {
        let uuid1 = UUIDv5.bookID(asin: nil, isbn: "978-0-13-468599-1", title: "Title", author: "Author")
        let uuid2 = UUIDv5.bookID(asin: nil, isbn: "978-0-13-468599-1", title: nil, author: nil)
        #expect(uuid1 == uuid2)
    }

    @Test func bookIDUsesTitleAuthorAsFallback() {
        let uuid1 = UUIDv5.bookID(asin: nil, isbn: nil, title: "My Book", author: "Jane Doe")
        let uuid2 = UUIDv5.bookID(asin: nil, isbn: nil, title: "My Book", author: "Jane Doe")
        #expect(uuid1 == uuid2)
    }

    @Test func bookIDNormalizesInput() {
        let uuid1 = UUIDv5.bookID(asin: nil, isbn: nil, title: "  My Book  ", author: "  Jane Doe  ")
        let uuid2 = UUIDv5.bookID(asin: nil, isbn: nil, title: "my book", author: "jane doe")
        #expect(uuid1 == uuid2)
    }
}
