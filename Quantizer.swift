import AppKit
import CoreGraphics
import ImageIO

struct QuantizationOptions {
    var numberOfColors: Int = 256
    var dithering: Bool = false
    var ieMode: Bool = false
    var speed: Int = 3
}

struct QuantizationResult {
    var image: NSImage
    var pngData: Data
}

enum QuantizationError: Error, LocalizedError {
    case failedToCreateAttr
    case failedToCreateImage
    case failedToQuantize(liq_error)
    case failedToRemap(liq_error)
    case failedToGetPixelData
    case failedToCreatePNG

    var errorDescription: String? {
        switch self {
        case .failedToCreateAttr: return "Failed to create quantization attributes"
        case .failedToCreateImage: return "Failed to create quantization image"
        case .failedToQuantize(let e): return "Quantization failed (\(e.rawValue))"
        case .failedToRemap(let e): return "Remapping failed (\(e.rawValue))"
        case .failedToGetPixelData: return "Failed to get pixel data from image"
        case .failedToCreatePNG: return "Failed to create PNG data"
        }
    }
}

actor Quantizer {

    func quantize(cgImage: CGImage, options: QuantizationOptions) throws -> QuantizationResult {
        let width = cgImage.width
        let height = cgImage.height
        let pixelCount = width * height

        // Draw into RGBA context to get raw pixel bytes
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw QuantizationError.failedToGetPixelData
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = context.data else {
            throw QuantizationError.failedToGetPixelData
        }

        // Undo premultiplication for libimagequant (it expects straight alpha)
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: pixelCount * 4)
        for i in 0..<pixelCount {
            let offset = i * 4
            let a = Int(pixels[offset + 3])
            if a > 0 && a < 255 {
                pixels[offset + 0] = UInt8(min(255, Int(pixels[offset + 0]) * 255 / a))
                pixels[offset + 1] = UInt8(min(255, Int(pixels[offset + 1]) * 255 / a))
                pixels[offset + 2] = UInt8(min(255, Int(pixels[offset + 2]) * 255 / a))
            }
        }

        // Create libimagequant attr
        guard let attr = liq_attr_create() else {
            throw QuantizationError.failedToCreateAttr
        }
        defer { liq_attr_destroy(attr) }

        liq_set_max_colors(attr, Int32(min(options.numberOfColors, 256)))
        liq_set_speed(attr, Int32(options.speed))

        if options.ieMode {
            liq_set_min_opacity(attr, 65)
        }

        // Create libimagequant image
        guard let liqImage = liq_image_create_rgba(attr, pixelData, Int32(width), Int32(height), 0) else {
            throw QuantizationError.failedToCreateImage
        }
        defer { liq_image_destroy(liqImage) }

        // Quantize
        var resultPtr: OpaquePointer?
        let quantErr = liq_image_quantize(liqImage, attr, &resultPtr)
        guard quantErr == LIQ_OK, let result = resultPtr else {
            throw QuantizationError.failedToQuantize(quantErr)
        }
        defer { liq_result_destroy(result) }

        // Set dithering
        liq_set_dithering_level(result, options.dithering ? 1.0 : 0.0)

        // Remap image
        let bufferSize = pixelCount
        let remapped = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { remapped.deallocate() }

        let remapErr = liq_write_remapped_image(result, liqImage, remapped, bufferSize)
        guard remapErr == LIQ_OK else {
            throw QuantizationError.failedToRemap(remapErr)
        }

        // Get palette
        guard let palettePtr = liq_get_palette(result) else {
            throw QuantizationError.failedToQuantize(LIQ_OK)
        }
        let palette = palettePtr.pointee
        let colorCount = Int(palette.count)

        // Build RGBA PNG from palette + indexed data
        let outputPixels = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount * 4)
        defer { outputPixels.deallocate() }

        withUnsafePointer(to: palette.entries) { entriesPtr in
            entriesPtr.withMemoryRebound(to: liq_color.self, capacity: 256) { colors in
                for i in 0..<pixelCount {
                    let idx = Int(remapped[i])
                    let color = colors[idx]
                    let offset = i * 4
                    outputPixels[offset + 0] = color.r
                    outputPixels[offset + 1] = color.g
                    outputPixels[offset + 2] = color.b
                    outputPixels[offset + 3] = color.a
                }
            }
        }

        // Create CGImage from RGBA output via data provider
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let dataLength = pixelCount * 4
        guard let dataProvider = CGDataProvider(data: Data(bytes: outputPixels, count: dataLength) as CFData) else {
            throw QuantizationError.failedToCreatePNG
        }
        guard let outputCGImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw QuantizationError.failedToCreatePNG
        }

        // Write PNG via CGImageDestination
        guard let pngData = createPNGData(from: outputCGImage) else {
            throw QuantizationError.failedToCreatePNG
        }

        let nsImage = NSImage(cgImage: outputCGImage, size: NSSize(width: width, height: height))
        return QuantizationResult(image: nsImage, pngData: pngData)
    }

    private func createPNGData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            return nil
        }
        return data as Data
    }
}
