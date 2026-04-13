import SwiftUI
import CommonCrypto

// =========================================
// === Memory & Disk Image Cache ===
// === Drop-in replacement for AsyncImage ===
// =========================================

/// Thread-safe in-memory and on-disk image cache.
/// Prevents repeated downloads of the same image (avatars, tour photos, collections)
/// persisting them across app sessions to drastically improve load times.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let diskCacheURL: URL

    private init() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("ImageCache")
        
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        self.diskCacheURL = cacheDir
    }

    private func md5(_ string: String) -> String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        
        if let d = string.data(using: .utf8) {
            _ = d.withUnsafeBytes { body -> String in
                CC_MD5(body.baseAddress, CC_LONG(d.count), &digest)
                return ""
            }
        }
        return (0..<length).reduce("") {
            $0 + String(format: "%02x", digest[$1])
        }
    }

    private func diskURL(for url: URL) -> URL {
        let hash = md5(url.absoluteString)
        return diskCacheURL.appendingPathComponent(hash)
    }

    func image(for url: URL) -> UIImage? {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        
        let fileURL = diskURL(for: url)
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            storeInMemory(image, for: url)
            return image
        }
        
        return nil
    }

    func store(_ image: UIImage, for url: URL) {
        storeInMemory(image, for: url)
        
        // Store on disk asynchronously
        let fileURL = diskURL(for: url)
        Task.detached(priority: .background) {
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL)
            }
        }
    }
    
    private func storeInMemory(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

/// A cached version of AsyncImage. Uses ImageCache to avoid re-downloading
/// images that have already been fetched during this session or previous sessions.
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
        guard let url = url, !isLoading else { return }

        // Check memory and disk cache first
        if let cached = ImageCache.shared.image(for: url) {
            self.uiImage = cached
            return
        }

        isLoading = true
        Task.detached(priority: .userInitiated) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    await MainActor.run { self.isLoading = false }
                    return
                }
                
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
