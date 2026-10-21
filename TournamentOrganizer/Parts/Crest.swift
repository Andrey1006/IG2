import SwiftUI
import PhotosUI
import UIKit

enum Crest {
    private static let cache = NSCache<NSData, UIImage>()

    static func image(_ data: Data) -> UIImage? {
        let key = data as NSData
        if let hit = cache.object(forKey: key) { return hit }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    static func shrink(_ image: UIImage, side: CGFloat = 180) -> Data? {
        let short = min(image.size.width, image.size.height)
        guard short > 0 else { return nil }
        let scale = side / short
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2, width: drawn.width, height: drawn.height))
        }
        return square.jpegData(compressionQuality: 0.75)
    }
}

struct CrestPicker: View {
    @Binding var crest: Data?
    let kit: Int
    var size: CGFloat = 56

    @State private var library = false
    @State private var camera = false
    @State private var item: PhotosPickerItem?

    var body: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    camera = true
                } label: {
                    Label("Take photo", systemImage: "camera")
                }
            }
            Button {
                library = true
            } label: {
                Label("Choose from library", systemImage: "photo.on.rectangle")
            }
            if crest != nil {
                Button(role: .destructive) {
                    crest = nil
                    Buzz.tick()
                } label: {
                    Label("Remove crest", systemImage: "trash")
                }
            }
        } label: {
            Kit(index: kit, size: size, crest: crest)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: crest == nil ? "camera.fill" : "pencil")
                        .font(.system(size: size * 0.2, weight: .heavy))
                        .foregroundColor(Turf.ink)
                        .frame(width: size * 0.4, height: size * 0.4)
                        .background(Circle().fill(Turf.floodlight))
                        .overlay(Circle().stroke(Turf.night, lineWidth: 2))
                        .offset(x: 4, y: 4)
                }
        }
        .photosPicker(isPresented: $library, selection: $item, matching: .images)
        .onChange(of: item) { picked in
            guard let picked else { return }
            Task {
                if let data = try? await picked.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let small = Crest.shrink(image) {
                    crest = small
                    Buzz.success()
                }
                item = nil
            }
        }
        .fullScreenCover(isPresented: $camera) {
            CameraShot { image in
                if let small = Crest.shrink(image) {
                    crest = small
                    Buzz.success()
                }
            }
            .ignoresSafeArea()
        }
    }
}

struct CameraShot: UIViewControllerRepresentable {
    let onShot: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraShot

        init(_ parent: CameraShot) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
                parent.onShot(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
