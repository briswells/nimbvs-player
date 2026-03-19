import UIKit

// MARK: - ImageCacheService

/// Actor-based image caching service with both memory and disk caches.
///
/// Images are first checked in the in-memory `NSCache`, then on disk in the
/// `Caches/CoverArt/` directory, and finally downloaded from the network.
actor ImageCacheService {

    // MARK: - Shared

    static let shared = ImageCacheService()

    // MARK: - Properties

    private let memoryCache = NSCache<NSString, UIImage>()
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500_000_000 // 500MB

    // MARK: - Init

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("CoverArt", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50_000_000 // 50MB
    }

    // MARK: - Public API

    /// Retrieves an image for the given URL, checking memory cache, disk cache, then network.
    ///
    /// - Parameters:
    ///   - url: The remote URL to download the image from if not cached.
    ///   - cacheKey: A unique key used to store and retrieve the image from caches.
    /// - Returns: The loaded `UIImage`.
    func image(for url: URL, cacheKey: String) async throws -> UIImage {
        let nsKey = NSString(string: cacheKey)

        // Check memory cache
        if let cached = memoryCache.object(forKey: nsKey) {
            return cached
        }

        // Check disk cache
        let diskPath = cacheDirectory.appendingPathComponent(cacheKey.replacingOccurrences(of: "/", with: "_"))
        if let data = try? Data(contentsOf: diskPath),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: nsKey, cost: data.count)
            return image
        }

        // Download from network
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        // Save to both caches
        memoryCache.setObject(image, forKey: nsKey, cost: data.count)
        try? data.write(to: diskPath)

        return image
    }

    /// Clears both memory and disk caches.
    func clearCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
