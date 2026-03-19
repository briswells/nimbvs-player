import SwiftUI

// MARK: - CoverImageView

/// Displays a cover image for a library item, loading it asynchronously
/// through `ImageCacheService` with memory and disk caching.
///
/// Shows a `ProgressView` while loading and a placeholder icon on failure.
struct CoverImageView: View {

    // MARK: - Properties

    let itemId: String
    let serverService: ServerService
    let serverId: UUID
    var width: CGFloat = NimbusTheme.Dimensions.coverThumbnailSize

    @State private var image: UIImage?
    @State private var isLoading = true

    // MARK: - Body

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                    .fill(NimbusTheme.Colors.surfaceOverlay)
                    .overlay {
                        ProgressView()
                            .tint(NimbusTheme.Colors.textTertiary)
                    }
            } else {
                RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                    .fill(NimbusTheme.Colors.surfaceOverlay)
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    }
            }
        }
        .frame(width: width, height: width)
        .clipShape(RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius))
        .task {
            await loadImage()
        }
    }

    // MARK: - Private

    private func loadImage() async {
        let cacheKey = "\(serverId.uuidString)_\(itemId)_\(Int(width))"

        // Try disk cache first (works offline)
        if let cached = await ImageCacheService.shared.cachedImage(cacheKey: cacheKey) {
            self.image = cached
            isLoading = false
            return
        }

        // Try any cached size for this item (offline fallback)
        let anySizeKey = "\(serverId.uuidString)_\(itemId)"
        if let cached = await ImageCacheService.shared.cachedImageWithPrefix(anySizeKey) {
            self.image = cached
            isLoading = false
            return
        }

        // Fetch from network
        guard let client = serverService.client(for: serverId),
              let url = client.coverURL(itemId: itemId, width: Int(width * UIScreen.main.scale)) else {
            isLoading = false
            return
        }

        do {
            let loaded = try await ImageCacheService.shared.image(for: url, cacheKey: cacheKey)
            self.image = loaded
        } catch {
            // Silently fail -- show placeholder
        }
        isLoading = false
    }
}
