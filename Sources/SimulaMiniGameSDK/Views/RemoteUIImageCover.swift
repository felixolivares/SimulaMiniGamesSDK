import SwiftUI
import UIKit

/// UIImageView subclass that refuses intrinsic sizing — decoded GIF raster sizes were expanding SwiftUI carousel cells.
private final class NonIntrinsicCoverImageView: UIImageView {

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        contentMode = .scaleAspectFill
        clipsToBounds = true
        backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.04)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}

/// Loads remote GIF / JPEG / PNG with **`UIImageView`** so GIFs animate (SwiftUI `AsyncImage` is static).
struct RemoteUIImageCover: UIViewRepresentable {

    final class Coordinator {
        private var task: Task<Void, Never>?

        func cancel() {
            task?.cancel()
            task = nil
        }

        func load(from url: URL, into imageView: UIImageView) {
            cancel()
            imageView.image = nil

            task = Task {
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard !Task.isCancelled else { return }
                    guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else { return }

                    let decoded = await Task.detached(priority: .utility) {
                        RasterImageDecoder.uiImage(decoding: data)
                    }.value

                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        imageView.image = decoded
                        if let frames = decoded?.images, frames.count > 1 {
                            imageView.startAnimating()
                        }
                        imageView.invalidateIntrinsicContentSize()
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                }
            }
        }

        deinit {
            cancel()
        }
    }

    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        NonIntrinsicCoverImageView()
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        context.coordinator.load(from: url, into: uiView)
    }

    static func dismantleUIView(_ uiView: UIImageView, coordinator: Coordinator) {
        coordinator.cancel()
        uiView.image = nil
    }
}
