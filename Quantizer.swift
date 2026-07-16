import AppKit
import Accelerate
import CoreGraphics

struct QuantizationOptions {
    var numberOfColors: Int = 256
    var dithering: Bool = false
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
        // Slider scrubbing queues multiple requests on this actor; skip any
        // whose task was already cancelled by a newer request.
        try Task.checkCancellation()

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
        var buffer = vImage_Buffer(
            data: pixelData,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: width * 4
        )
        guard vImageUnpremultiplyData_RGBA8888(&buffer, &buffer, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            throw QuantizationError.failedToGetPixelData
        }

        // Create libimagequant attr
        guard let attr = liq_attr_create() else {
            throw QuantizationError.failedToCreateAttr
        }
        defer { liq_attr_destroy(attr) }

        liq_set_max_colors(attr, Int32(min(options.numberOfColors, 256)))
        liq_set_speed(attr, Int32(options.speed))

        // Create libimagequant image
        guard let liqImage = liq_image_create_rgba(attr, pixelData, Int32(width), Int32(height), 0) else {
            throw QuantizationError.failedToCreateImage
        }
        defer { liq_image_destroy(liqImage) }

        // Quantize
        try Task.checkCancellation()
        var resultPtr: OpaquePointer?
        let quantErr = liq_image_quantize(liqImage, attr, &resultPtr)
        guard quantErr == LIQ_OK, let result = resultPtr else {
            throw QuantizationError.failedToQuantize(quantErr)
        }
        defer { liq_result_destroy(result) }

        // Set dithering
        liq_set_dithering_level(result, options.dithering ? 1.0 : 0.0)

        // Remap image
        let remapped = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount)
        defer { remapped.deallocate() }

        let remapErr = liq_write_remapped_image(result, liqImage, remapped, pixelCount)
        guard remapErr == LIQ_OK else {
            throw QuantizationError.failedToRemap(remapErr)
        }

        // Get palette
        guard let palettePtr = liq_get_palette(result) else {
            throw QuantizationError.failedToQuantize(LIQ_OK)
        }
        let palette = palettePtr.pointee
        let colorCount = Int(palette.count)

        let paletteEntries: [IndexedPNGEncoder.PaletteEntry] = withUnsafePointer(to: palette.entries) { entriesPtr in
            entriesPtr.withMemoryRebound(to: liq_color.self, capacity: 256) { colors in
                (0..<colorCount).map { i in
                    IndexedPNGEncoder.PaletteEntry(red: colors[i].r, green: colors[i].g, blue: colors[i].b, alpha: colors[i].a)
                }
            }
        }
        let indices = [UInt8](UnsafeBufferPointer(start: remapped, count: pixelCount))

        // Encode a real indexed PNG (PLTE + tRNS); ImageIO can only write
        // truecolor, which would forfeit most of the size reduction.
        guard let pngData = IndexedPNGEncoder.encode(
            width: width, height: height, palette: paletteEntries, pixels: indices
        ) else {
            throw QuantizationError.failedToCreatePNG
        }

        guard let nsImage = Self.makeDisplayImage(
            palette: paletteEntries, indices: indices, width: width, height: height
        ) else {
            throw QuantizationError.failedToCreatePNG
        }

        return QuantizationResult(image: nsImage, pngData: pngData)
    }

    /// Expands palette + indices into an RGBA CGImage for on-screen display.
    private static func makeDisplayImage(
        palette: [IndexedPNGEncoder.PaletteEntry],
        indices: [UInt8],
        width: Int,
        height: Int
    ) -> NSImage? {
        let pixelCount = width * height
        var outputPixels = [UInt8](repeating: 0, count: pixelCount * 4)
        for i in 0..<pixelCount {
            let color = palette[Int(indices[i])]
            let offset = i * 4
            outputPixels[offset + 0] = color.red
            outputPixels[offset + 1] = color.green
            outputPixels[offset + 2] = color.blue
            outputPixels[offset + 3] = color.alpha
        }

        guard let dataProvider = CGDataProvider(data: Data(outputPixels) as CFData),
              let outputCGImage = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                  provider: dataProvider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            return nil
        }

        return NSImage(cgImage: outputCGImage, size: NSSize(width: width, height: height))
    }
}
