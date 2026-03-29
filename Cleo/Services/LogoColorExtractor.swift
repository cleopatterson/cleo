import UIKit
import SwiftUI

/// Extracts dominant colour from a logo image using Core Image.
/// Falls back gracefully if extraction fails.
enum LogoColorExtractor {

    /// Extract the dominant vibrant colour from an image.
    /// Returns a hex string like "#b794f6".
    static func extractDominantColor(from image: UIImage) -> String? {
        guard image.cgImage != nil else { return nil }

        // Scale down for performance
        let size = CGSize(width: 50, height: 50)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: size))
        guard let smallImage = UIGraphicsGetImageFromCurrentImageContext(),
              let smallCG = smallImage.cgImage else { return nil }

        // Read pixel data
        let width = smallCG.width
        let height = smallCG.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(smallCG, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Bucket colours, skip near-white, near-black, and low-saturation
        var buckets: [String: (count: Int, r: Int, g: Int, b: Int)] = [:]

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = Int(rawData[offset])
                let g = Int(rawData[offset + 1])
                let b = Int(rawData[offset + 2])
                let a = Int(rawData[offset + 3])

                guard a > 128 else { continue } // skip transparent

                let brightness = (r + g + b) / 3
                guard brightness > 30, brightness < 230 else { continue } // skip near-black/white

                // Check saturation — skip greys
                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let saturation = maxC > 0 ? Double(maxC - minC) / Double(maxC) : 0
                guard saturation > 0.15 else { continue }

                // Quantize to 32-level buckets for grouping
                let qr = (r / 32) * 32
                let qg = (g / 32) * 32
                let qb = (b / 32) * 32
                let key = "\(qr)-\(qg)-\(qb)"

                if var bucket = buckets[key] {
                    bucket.count += 1
                    bucket.r += r
                    bucket.g += g
                    bucket.b += b
                    buckets[key] = bucket
                } else {
                    buckets[key] = (1, r, g, b)
                }
            }
        }

        // Find the most common vibrant bucket
        guard let best = buckets.values.max(by: { $0.count < $1.count }) else { return nil }

        let avgR = best.r / best.count
        let avgG = best.g / best.count
        let avgB = best.b / best.count

        return String(format: "#%02X%02X%02X", avgR, avgG, avgB)
    }

    /// Extract from a URL (e.g. downloaded favicon/logo)
    static func extractDominantColor(from url: URL) async -> String? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        return extractDominantColor(from: image)
    }
}
