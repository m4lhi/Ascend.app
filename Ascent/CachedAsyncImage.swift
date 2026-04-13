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

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL

    private init() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        
        // Setup disk cache
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        diskCacheURL = paths[0].appendingPathComponent("AscentImageCache")
        if !fileManager.fileExists(atPath: diskCacheURL.path) {
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }

    private func diskURL(for url: URL) -> URL {
        let filename = String(url.absoluteString.hashValue)
        return diskCacheURL.appendingPathComponent(filename)
    }

    func image(for url: URL) -> UIImage? {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        
        // Check disk cache
        let fileURL = diskURL(for: url)
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            storeInMemory(image, for: url)
            return image
        }
        
        return nil
    }

    func store(_ image: UIImage, data: Data?, for url: URL) {
        storeInMemory(image, for: url)
        
        // Store to disk asynchronously
        if let dataToSave = data {
            let fileURL = diskURL(for: url)
            Task.detached(priority: .background) {
                try? dataToSave.write(to: fileURL)
            }
        }
    }
    
    private func storeInMemory(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
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
        
        if let url = url, let cached = ImageCache.shared.image(for: url) {
            self._uiImage = State(initialValue: cached)
        } else {
            self._uiImage = State(initialValue: nil)
        }
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
                        ImageCache.shared.store(image, data: data, for: url)
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
