import PhotosUI
import SwiftUI
import UIKit

/// A kitchen photo, already shrunk and compressed for Claude. Kept in memory only.
struct KitchenPhoto: Identifiable {
    let id = UUID()
    let thumbnail: UIImage
    let jpeg: Data

    /// Longest side 1568 px: as much detail as Claude uses, without wasting upload time.
    init?(_ image: UIImage) {
        let maxSide: CGFloat = 1568
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = resized.jpegData(compressionQuality: 0.75) else { return nil }
        // A small copy for the grids, so a row of photos doesn't keep six big images on screen.
        thumbnail = resized.preparingThumbnail(of: CGSize(width: target.width * 0.25, height: target.height * 0.25)) ?? resized
        jpeg = data
    }
}

/// Zero-waste step: first ask whether to use kitchen photos this round, then collect them.
struct KitchenStep: View {
    @Binding var useKitchen: Bool?
    @Binding var photos: [KitchenPhoto]
    let onSkip: () -> Void

    static let maxPhotos = 6

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            StepHeader(art: Illustration.kitchenPhotos.image,
                       title: "Use up what's in your kitchen?",
                       subtitle: "Snap your fridge or pantry and Claude plans around what you already have.")

            if useKitchen != true {
                VStack(spacing: 12) {
                    ChoiceRow(icon: "camera", title: "Yes, add photos",
                              subtitle: "Half-used veg, leftovers and opened packs",
                              selected: false) {
                        withAnimation(.easeOut(duration: 0.2)) { useKitchen = true }
                    }
                    ChoiceRow(icon: "forward", title: "Not this time",
                              subtitle: "Shop for everything",
                              selected: useKitchen == false) {
                        useKitchen = false
                        onSkip()
                    }
                }
            } else {
                photoArea
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            KitchenCamera(photos: $photos, maxPhotos: Self.maxPhotos)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            loading = true
            Task {
                for item in items {
                    guard photos.count < Self.maxPhotos else { break }
                    guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                    // Shrinking a full-size photo takes a moment: do it off the main thread.
                    let photo = await Task.detached(priority: .userInitiated) {
                        UIImage(data: data).flatMap(KitchenPhoto.init)
                    }.value
                    if let photo { withAnimation { photos.append(photo) } }
                }
                pickerItems = []
                loading = false
            }
        }
    }

    private var photoArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !photos.isEmpty || loading {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(photos) { photo in
                        Image(uiImage: photo.thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    withAnimation { photos.removeAll { $0.id == photo.id } }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(.black.opacity(0.6), in: Circle())
                                }
                                .padding(6)
                                .accessibilityLabel("Remove photo")
                            }
                    }
                    if loading {
                        RoundedRectangle(cornerRadius: 14).fill(Theme.subtle)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(ProgressView().tint(Theme.secondary))
                    }
                }
            }

            if photos.count < Self.maxPhotos {
                HStack(spacing: 10) {
                    if CameraController.isAvailable {
                        Button { showingCamera = true } label: {
                            Label("Take photos", systemImage: "camera")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: Self.maxPhotos - photos.count,
                                 matching: .images) {
                        Label("From library", systemImage: "photo.on.rectangle")
                            .font(.sans(16, .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Theme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                    }
                }
            }

            Text("\(photos.count) of \(Self.maxPhotos) photos")
                .font(.sans(13)).foregroundStyle(Theme.secondary)

            SecurityNote(text: "Photos are sent to Claude only to make this plan. They aren't saved in the app.")

            Button("Changed my mind, skip this round") {
                photos = []
                useKitchen = false
                onSkip()
            }
            .font(.sans(14, .semibold))
            .foregroundStyle(Theme.secondary)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ChoiceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Theme.subtle, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.sans(16, .semibold)).foregroundStyle(Theme.ink)
                    Text(subtitle).font(.sans(13)).foregroundStyle(Theme.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .card(selected ? Theme.subtle : Theme.surface, stroke: selected ? Theme.ink : Theme.line)
        }
        .buttonStyle(.plain)
    }
}
