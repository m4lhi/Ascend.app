import SwiftUI
import Combine
import PhotosUI
import CoreLocation
import MapKit

// =========================================
// === DATEI: PhotoHighlights.swift ===
// === Fotos an GPS-Positionen pinnen ===
// =========================================

struct PhotoHighlight: Identifiable, Codable {
    let id: UUID
    let coordinate: CodableCoordinate
    let timestamp: Date
    let caption: String?
    var photoURL: String?

    // For local photos not yet uploaded
    var localImageData: Data?

    enum CodingKeys: String, CodingKey {
        case id, coordinate, timestamp, caption, photoURL
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

struct CodableCoordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

@MainActor
class PhotoHighlightManager: ObservableObject {
    @Published var highlights: [PhotoHighlight] = []

    func addPhoto(data: Data, at location: CLLocation, caption: String? = nil) {
        let highlight = PhotoHighlight(
            id: UUID(),
            coordinate: CodableCoordinate(location.coordinate),
            timestamp: Date(),
            caption: caption,
            photoURL: nil,
            localImageData: data
        )
        highlights.append(highlight)
    }

    func removeHighlight(id: UUID) {
        highlights.removeAll { $0.id == id }
    }

    /// Encode highlights to JSON for storage in tour
    func encodeHighlights() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Strip local image data for encoding
        let stripped = highlights.map { h in
            PhotoHighlight(id: h.id, coordinate: h.coordinate, timestamp: h.timestamp, caption: h.caption, photoURL: h.photoURL)
        }
        guard let data = try? encoder.encode(stripped) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decode highlights from stored JSON
    func decodeHighlights(from json: String) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = json.data(using: .utf8),
              let decoded = try? decoder.decode([PhotoHighlight].self, from: data) else { return }
        self.highlights = decoded
    }
}

// MARK: - Photo Capture Button (for LiveRecordView)
struct PhotoCaptureButton: View {
    let currentLocation: CLLocation?
    @ObservedObject var photoManager: PhotoHighlightManager
    @State private var showCamera = false
    @State private var showFallbackPicker = false
    @State private var selectedItem: PhotosPickerItem?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Group {
            if cameraAvailable {
                Button(action: { showCamera = true }) {
                    captureButtonLabel
                }
                .fullScreenCover(isPresented: $showCamera) {
                    CameraCaptureView { imageData in
                        if let data = imageData, let location = currentLocation {
                            photoManager.addPhoto(data: data, at: location)
                        }
                    }
                    .ignoresSafeArea()
                }
            } else {
                // Fallback: photo library on simulator or devices without camera
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    captureButtonLabel
                }
                .onChange(of: selectedItem) { _, newItem in
                    guard let item = newItem, let location = currentLocation else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            photoManager.addPhoto(data: data, at: location)
                        }
                        selectedItem = nil
                    }
                }
            }
        }
    }

    private var captureButtonLabel: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 40, height: 40)
            Image(systemName: "camera.fill")
                .font(DesignSystem.Typography.appFont(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.accent)

            if !photoManager.highlights.isEmpty {
                Text("\(photoManager.highlights.count)")
                    .font(DesignSystem.Typography.appFont(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(3)
                    .background(Circle().fill(Color.orange))
                    .offset(x: 14, y: -14)
            }
        }
    }
}

// MARK: - Camera Capture (UIImagePickerController wrapper)
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (Data?) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data?) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (Data?) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image.jpegData(compressionQuality: 0.8))
            } else {
                onCapture(nil)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
            dismiss()
        }
    }
}

// MARK: - Photo Highlight Map Content (use inside Map { } block)
struct PhotoHighlightMapContent: MapContent {
    let highlights: [PhotoHighlight]

    var body: some MapContent {
        ForEach(highlights) { highlight in
            Annotation("", coordinate: highlight.clCoordinate) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                    if let data = highlight.localImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "photo.fill")
                            .font(DesignSystem.Typography.appFont(size: 14))
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                }
            }
        }
    }
}

// MARK: - Photo Highlights Strip (horizontal scroll below map)
struct PhotoHighlightsStrip: View {
    let highlights: [PhotoHighlight]
    var onSelect: ((PhotoHighlight) -> Void)? = nil
    var onDelete: ((UUID) -> Void)? = nil

    var body: some View {
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(DesignSystem.Colors.accent)
                    Text("Photo Highlights")
                        .font(DesignSystem.Typography.appFont(style: .subheadline))
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(highlights.count)")
                        .font(DesignSystem.Typography.appFont(style: .caption))
                        .foregroundColor(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(highlights) { highlight in
                            photoThumbnail(highlight)
                        }
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func photoThumbnail(_ highlight: PhotoHighlight) -> some View {
        Button(action: { onSelect?(highlight) }) {
            ZStack(alignment: .topTrailing) {
                if let data = highlight.localImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let url = highlight.photoURL, let photoURL = URL(string: url) {
                    CachedAsyncImage(url: photoURL) { image in
                        image.resizable().scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                    }
                }

                if onDelete != nil {
                    Button(action: { onDelete?(highlight.id) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(DesignSystem.Typography.appFont(size: 18))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .offset(x: 4, y: -4)
                }
            }
        }
    }
}
