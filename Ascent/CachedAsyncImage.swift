import SwiftUI

// =========================================
// === In-Memory Image Cache ===
// === Drop-in replacement for AsyncImage ===
// =========================================

/// Thread-safe in-memory image cache with automatic size limit.
/// Prevents repeated downloads of the same image (avatars, tour photos)
/// that cause lag and bandwidth waste when scrolling feeds.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

/// A cached version of AsyncImage. Uses NSCache to avoid re-downloading
/// images that have already been fetched during this session.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage? = nil
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .onAppear { loadImage() }
            }
        }
    }

    private func loadImage() {
        guard let url, !isLoading else { return }

        // Check cache first
        if let cached = ImageCache.shared.image(for: url) {
            self.uiImage = cached
            return
        }

        isLoading = true
        Task.detached(priority: .utility) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    if let image = UIImage(data: data) {
                        ImageCache.shared.store(image, for: url)
                        self.uiImage = image
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}
