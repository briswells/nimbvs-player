import Foundation
import CommonCrypto

// MARK: - UUIDv5

/// Deterministic UUID v5 generation per RFC 4122 using SHA-1 hashing.
enum UUIDv5 {

    /// Fixed namespace UUID for Nimbus Player identifiers.
    static let nimbusNamespace = UUID(uuidString: "8bcf5e6a-3b2a-4f7d-9c1e-a5d8f2b7c4e1")!

    // MARK: - Generate

    /// Generates a deterministic UUID v5 from the given namespace and name.
    ///
    /// The algorithm follows RFC 4122 Section 4.3:
    /// 1. Concatenate the namespace UUID bytes with the name's UTF-8 bytes
    /// 2. Compute SHA-1 hash of the concatenated data
    /// 3. Set version nibble to 5 and variant bits to RFC 4122
    /// 4. Return the first 16 bytes as a UUID
    static func generate(namespace: UUID, name: String) -> UUID {
        // Get namespace bytes in big-endian order
        let nsUUID = namespace.uuid
        var namespaceBytes: [UInt8] = [
            nsUUID.0, nsUUID.1, nsUUID.2, nsUUID.3,
            nsUUID.4, nsUUID.5, nsUUID.6, nsUUID.7,
            nsUUID.8, nsUUID.9, nsUUID.10, nsUUID.11,
            nsUUID.12, nsUUID.13, nsUUID.14, nsUUID.15
        ]

        // Append name UTF-8 bytes
        let nameBytes = Array(name.utf8)
        namespaceBytes.append(contentsOf: nameBytes)

        // SHA-1 hash
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        namespaceBytes.withUnsafeBufferPointer { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }

        // Set version to 5 (byte 6: high nibble = 0101)
        hash[6] = (hash[6] & 0x0F) | 0x50

        // Set variant to RFC 4122 (byte 8: top 2 bits = 10)
        hash[8] = (hash[8] & 0x3F) | 0x80

        // Construct UUID from first 16 bytes
        let uuid = UUID(uuid: (
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15]
        ))

        return uuid
    }

    // MARK: - Book ID

    /// Generates a deterministic book identifier UUID.
    ///
    /// Priority order:
    /// 1. ASIN (if provided)
    /// 2. ISBN (if provided)
    /// 3. Normalized title + author combination
    ///
    /// - Parameters:
    ///   - asin: Amazon Standard Identification Number
    ///   - isbn: International Standard Book Number
    ///   - title: Book title (used as fallback)
    ///   - author: Book author (used as fallback)
    /// - Returns: A deterministic UUID v5 for the book
    static func bookID(
        asin: String? = nil,
        isbn: String? = nil,
        title: String? = nil,
        author: String? = nil
    ) -> UUID {
        let name: String

        if let asin, !asin.isEmpty {
            name = asin
        } else if let isbn, !isbn.isEmpty {
            name = isbn
        } else {
            let normalizedTitle = normalizeForID(title ?? "")
            let normalizedAuthor = normalizeForID(author ?? "")
            name = "\(normalizedTitle):\(normalizedAuthor)"
        }

        return generate(namespace: nimbusNamespace, name: name)
    }

    // MARK: - Private

    /// Normalizes a string for use in ID generation by lowercasing and trimming whitespace.
    private static func normalizeForID(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
