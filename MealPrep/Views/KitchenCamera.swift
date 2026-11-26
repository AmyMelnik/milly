import AVFoundation
import SwiftUI
import UIKit

/// Full-screen camera that keeps shooting: every tap of the shutter adds a photo to the strip at the
/// bottom, where it can be removed again. No "Use photo" step in between.
struct KitchenCamera: View {
    @Binding var photos: [KitchenPhoto]
    let maxPhotos: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var camera = CameraController()
    /// Shots taken but still being shrunk and compressed.
    @State private var processing = 0
    @State private var flash = false

    private var room: Int { maxPhotos - photos.count - processing }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.status {
            case .ready, .starting:
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            case .denied:
                denied
            case .unavailable:
                message("No camera available", detail: "Add photos from your library instead.")
            }

            Color.white
                .opacity(flash ? 0.7 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                if camera.status == .ready || camera.status == .starting {
                    bottomPanel
                }
            }
        }
        .statusBarHidden()
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel("Close camera")
            Spacer()
            Text("\(photos.count + processing) of \(maxPhotos)")
                .font(.sans(14, .semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(.black.opacity(0.45), in: Capsule())
                .contentTransition(.numericText())
                .animation(.snappy, value: photos.count + processing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var bottomPanel: some View {
        VStack(spacing: 18) {
            strip
            HStack {
                Color.clear.frame(width: 76, height: 44)
                Spacer()
                shutter
                Spacer()
                Button { dismiss() } label: {
                    Text("Done")
                        .font(.sans(16, .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 76, height: 44)
                        .background(.white, in: Capsule())
                }
                .opacity(photos.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 24)
            Text(room > 0 ? "One shelf or drawer per photo works best." : "That's the maximum. Remove one to take another.")
                .font(.sans(13))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.55))
    }

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photos) { photo in
                        Image(uiImage: photo.thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 62, height: 62)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    withAnimation(.snappy) { photos.removeAll { $0.id == photo.id } }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(.black.opacity(0.75), in: Circle())
                                        .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1))
                                }
                                .offset(x: 6, y: -6)
                                .accessibilityLabel("Remove photo")
                            }
                            .id(photo.id)
                            .transition(.scale.combined(with: .opacity))
                    }
                    ForEach(0..<processing, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.15))
                            .frame(width: 62, height: 62)
                            .overlay(ProgressView().tint(.white))
                    }
                    ForEach(0..<max(0, room), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: 62, height: 62)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .onChange(of: photos.count) {
                if let last = photos.last { withAnimation { proxy.scrollTo(last.id, anchor: .trailing) } }
            }
        }
        .frame(height: 74)
    }

    private var shutter: some View {
        Button(action: shoot) {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 4).frame(width: 78, height: 78)
                Circle().fill(.white).frame(width: 64, height: 64)
            }
        }
        .buttonStyle(ShutterStyle())
        .disabled(room <= 0 || camera.status != .ready)
        .opacity(room <= 0 ? 0.35 : 1)
        .accessibilityLabel("Take photo")
    }

    private var denied: some View {
        VStack(spacing: 16) {
            Art(.cameraDenied, size: 110, tilt: -4)
            message("Camera access is off",
                    detail: "Allow camera access in Settings to snap your fridge, or add photos from your library.")
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.sans(16, .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 22)
            .frame(height: 46)
            .background(.white, in: Capsule())
        }
    }

    private func message(_ title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.sans(18, .semibold)).foregroundStyle(.white)
            Text(detail).font(.sans(14)).foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    // MARK: Shooting

    private func shoot() {
        guard room > 0 else { return }
        processing += 1
        withAnimation(.easeOut(duration: 0.05)) { flash = true }
        withAnimation(.easeIn(duration: 0.25).delay(0.05)) { flash = false }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            let data = await camera.capture()
            // Shrinking and compressing takes a moment, so it happens off the main thread.
            let photo = await Task.detached(priority: .userInitiated) {
                data.flatMap(UIImage.init(data:)).flatMap(KitchenPhoto.init)
            }.value
            processing -= 1
            if let photo, photos.count < maxPhotos {
                withAnimation(.snappy) { photos.append(photo) }
            }
        }
    }
}

private struct ShutterStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Camera

/// Runs the capture session on its own queue and hands back JPEG data for each shot.
@MainActor
@Observable
final class CameraController {
    enum Status { case starting, ready, denied, unavailable }

    private(set) var status: Status = .starting
    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private let queue = DispatchQueue(label: "kitchen.camera")
    @ObservationIgnored private var configured = false
    @ObservationIgnored private var pending: [Int64: PhotoDelegate] = [:]

    static var isAvailable: Bool { AVCaptureDevice.default(for: .video) != nil }

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { status = .denied; return }
        default:
            status = .denied
            return
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            status = .unavailable
            return
        }
        let session = session, output = output, alreadyConfigured = configured
        configured = true
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                if !alreadyConfigured {
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    if session.canAddInput(input) { session.addInput(input) }
                    if session.canAddOutput(output) {
                        session.addOutput(output)
                        output.maxPhotoQualityPrioritization = .speed
                    }
                    session.commitConfiguration()
                }
                if !session.isRunning { session.startRunning() }
                done.resume()
            }
        }
        status = .ready
    }

    func stop() {
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    /// Takes one photo. Returns nil if the shot failed.
    func capture() async -> Data? {
        guard status == .ready else { return nil }
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.photoQualityPrioritization = .speed
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90 // The app is portrait-only.
        }
        return await withCheckedContinuation { continuation in
            let id = settings.uniqueID
            let delegate = PhotoDelegate { [weak self] data in
                Task { @MainActor in self?.pending[id] = nil }
                continuation.resume(returning: data)
            }
            pending[id] = delegate
            output.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let done: (Data?) -> Void
    init(done: @escaping (Data?) -> Void) { self.done = done }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        done(error == nil ? photo.fileDataRepresentation() : nil)
    }
}

/// The live camera image.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
