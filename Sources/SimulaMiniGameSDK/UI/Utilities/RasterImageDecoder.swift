import ImageIO
import UIKit

/// Builds **`UIImage`** from raw bytes — multi-frame GIFs need **ImageIO**; **`UIImage(data:)`** usually drops animation.
enum RasterImageDecoder {

    nonisolated static func uiImage(decoding data: Data) -> UIImage? {
        guard !data.isEmpty else { return nil }

        let suppressCache = [
            kCGImageSourceShouldCache: false,
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, suppressCache) else {
            return UIImage(data: data)
        }

        let frameCount = CGImageSourceGetCount(source)

        let looksLikeGifSignature = gifSignatureMatches(data.prefix(8))

        // Single-frame payloads can still be labelled *.gif → fall back to UIImage.
        if looksLikeGifSignature || frameCount > 1, let gif = AnimatedGIFCompositor.image(source: source, frameCountLimit: 120) {
            return gif
        }

        return UIImage(data: data)
    }

    nonisolated private static func gifSignatureMatches(_ prefix: Data) -> Bool {
        guard prefix.count >= 6 else { return false }
        /// `GIF87a` / `GIF89a`.
        let sig87 = Data([0x47, 0x49, 0x46, 0x38, 0x37, 0x61])
        let sig89 = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])
        return prefix.starts(with: sig87) || prefix.starts(with: sig89)
    }
}

// MARK: - GIF composition

private enum AnimatedGIFCompositor {

    nonisolated static func image(source: CGImageSource, frameCountLimit: Int) -> UIImage? {
        let countRaw = CGImageSourceGetCount(source)
        guard countRaw > 1 else { return nil }

        let count = Int(min(UInt(countRaw), UInt(frameCountLimit)))
        guard count > 1 else { return nil }

        var frames: [UIImage] = []
        frames.reserveCapacity(count)
        var totalDuration: CGFloat = 0

        for i in 0 ..< count {
            guard let cg = cgFrame(from: source, index: i) else { continue }
            frames.append(UIImage(cgImage: cg))

            totalDuration += gifDelay(for: source, index: i)
        }

        guard frames.count >= 2 else {
            return nil
        }

        let duration = Double(totalDuration < 1e-4 ? 0.05 * CGFloat(frames.count) : totalDuration)
        return UIImage.animatedImage(with: frames, duration: duration)
    }

    nonisolated private static func gifDelay(for src: CGImageSource, index: Int) -> CGFloat {
        var delay: CGFloat = 0.1

        guard
            let props = CGImageSourceCopyPropertiesAtIndex(src, index, nil) as? [CFString: Any],
            let gifDict = props[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return delay
        }

        let clampDelayKey = kCGImagePropertyGIFDelayTime
        let raw = (gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
            ?? (gifDict[clampDelayKey] as? NSNumber)?.doubleValue
            ?? 0

        if raw > .ulpOfOne {
            delay = CGFloat(raw)
            if delay < 0.02 {
                delay = 0.1
            }
            return delay
        }
        return delay
    }

    nonisolated private static func cgFrame(from source: CGImageSource, index: Int) -> CGImage? {
        let targetMaxEdge: CGFloat = 960
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: targetMaxEdge,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        if let thumb = CGImageSourceCreateThumbnailAtIndex(source, index, thumbOpts as CFDictionary) {
            return thumb
        }
        return CGImageSourceCreateImageAtIndex(source, index, nil)
    }
}