//
//  StoredPhoto.swift
//  Systems Inspector
//

import ImageIO
import UIKit

/// A photo reduced to a 1600-pixel long edge before it is stored as JPEG.
enum StoredPhoto {
    static let maxLongEdge: CGFloat = 1600

    static func fitting(_ image: UIImage) -> UIImage {
        let pixels = pixelSize(of: image)
        let longEdge = max(pixels.width, pixels.height)
        guard longEdge > maxLongEdge, longEdge > 0 else { return image }
        let ratio = maxLongEdge / longEdge
        let fitted = CGSize(
            width: max(floor(pixels.width * ratio), 1),
            height: max(floor(pixels.height * ratio), 1)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: fitted, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: fitted))
        }
    }

    static func jpegData(from image: UIImage, quality: CGFloat = 0.8) -> Data? {
        fitting(image).jpegData(compressionQuality: quality)
    }

    static func prepared(from image: UIImage) async -> (image: UIImage, jpeg: Data)? {
        await offMain {
            let fitted = fitting(image)
            guard let jpeg = fitted.jpegData(compressionQuality: 0.8) else { return nil }
            return (fitted, jpeg)
        }
    }

    /// A SiteDocument photo becomes a JPEG. A PDF is returned unchanged.
    static func siteDocumentPhoto(
        data: Data,
        contentType: String,
        filename: String
    ) -> (data: Data, contentType: String, filename: String)? {
        if contentType == "public.pdf" {
            return (data, contentType, filename)
        }
        guard contentType == "public.jpeg" || contentType == "public.png" else { return nil }
        guard let image = UIImage(data: data), let jpeg = jpegData(from: image) else { return nil }
        return (jpeg, "public.jpeg", jpegFilename(filename))
    }

    static func siteDocumentPhotoOffMain(
        data: Data,
        contentType: String,
        filename: String
    ) async -> (data: Data, contentType: String, filename: String)? {
        await offMain {
            siteDocumentPhoto(data: data, contentType: contentType, filename: filename)
        }
    }

    static func thumbnail(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard maxPixelSize > 0,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func jpegFilename(_ filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        let stem = base.isEmpty ? "site-photo" : base
        return stem + ".jpg"
    }

    private static func pixelSize(of image: UIImage) -> CGSize {
        CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    private static func offMain<T>(_ work: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: work())
            }
        }
    }
}
