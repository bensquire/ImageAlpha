import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import ImageAlpha

/// End-to-end tests: source pixels → libimagequant → indexed PNG → decode.
struct QuantizerTests {

    // MARK: - Helpers

    /// A width×height image cycling through the given opaque RGB colors.
    private func makeImage(width: Int, height: Int, colors: [[UInt8]]) throws -> CGImage {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            let color = colors[i % colors.count]
            rgba[i * 4] = color[0]; rgba[i * 4 + 1] = color[1]; rgba[i * 4 + 2] = color[2]
            rgba[i * 4 + 3] = color.count > 3 ? color[3] : 255
        }
        return try makeTestCGImage(width: width, height: height, rgba: rgba)
    }

    private func decodeRGBA(_ pngData: Data) throws -> DecodedImage {
        try #require(DecodedImage(pngData: pngData))
    }

    private func uniqueColors(in rgba: [UInt8]) -> Set<[UInt8]> {
        var unique = Set<[UInt8]>()
        for i in stride(from: 0, to: rgba.count, by: 4) {
            unique.insert(Array(rgba[i..<(i + 4)]))
        }
        return unique
    }

    // MARK: - Output format

    @Test func producesIndexedColorTypePNG() async throws {
        // Arrange
        let image = try makeImage(width: 32, height: 32, colors: [[255, 0, 0], [0, 255, 0], [0, 0, 255]])
        let quantizer = Quantizer()

        // Act
        let result = try await quantizer.quantize(cgImage: image, options: QuantizationOptions())

        // Assert: IHDR byte 25 is the color type; 3 means indexed
        #expect(result.pngData[25] == 3)
    }

    @Test func outputDecodesToOriginalDimensions() async throws {
        // Arrange
        let image = try makeImage(width: 40, height: 24, colors: [[10, 20, 30], [200, 100, 0]])
        let quantizer = Quantizer()

        // Act
        let result = try await quantizer.quantize(cgImage: image, options: QuantizationOptions())
        let decoded = try decodeRGBA(result.pngData)

        // Assert
        #expect(decoded.width == 40)
        #expect(decoded.height == 24)
    }

    // MARK: - Color reduction

    @Test func reducesManyColorsToRequestedMaximum() async throws {
        // Arrange: 64x64 gradient with far more than 16 unique colors
        let width = 64, height = 64
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                rgba[i] = UInt8(x * 4); rgba[i + 1] = UInt8(y * 4); rgba[i + 2] = UInt8((x + y) * 2); rgba[i + 3] = 255
            }
        }
        let image = try makeTestCGImage(width: width, height: height, rgba: rgba)
        let quantizer = Quantizer()
        let options = QuantizationOptions(numberOfColors: 16)

        // Act
        let result = try await quantizer.quantize(cgImage: image, options: options)
        let decoded = try decodeRGBA(result.pngData)

        // Assert
        #expect(uniqueColors(in: decoded.rgba).count <= 16)
    }

    @Test func preservesSmallPaletteExactly() async throws {
        // Arrange: 4 distinct opaque colors, quantized to 256 (no reduction needed)
        let colors: [[UInt8]] = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 0]]
        let image = try makeImage(width: 32, height: 32, colors: colors)
        let quantizer = Quantizer()

        // Act
        let result = try await quantizer.quantize(cgImage: image, options: QuantizationOptions())
        let decoded = try decodeRGBA(result.pngData)
        let unique = uniqueColors(in: decoded.rgba)

        // Assert
        #expect(unique.count <= 4)
        for color in colors {
            let expected = [color[0], color[1], color[2], UInt8(255)]
            let matched = unique.contains { zip($0, expected).allSatisfy { abs(Int($0) - Int($1)) <= 2 } }
            #expect(matched, "expected \(expected) in quantized palette")
        }
    }

    // MARK: - Transparency

    @Test func preservesFullyTransparentPixels() async throws {
        // Arrange: left half transparent, right half opaque red
        let width = 16, height = 16
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in (width / 2)..<width {
                let i = (y * width + x) * 4
                rgba[i] = 255; rgba[i + 3] = 255
            }
        }
        let image = try makeTestCGImage(width: width, height: height, rgba: rgba)
        let quantizer = Quantizer()

        // Act
        let result = try await quantizer.quantize(cgImage: image, options: QuantizationOptions())
        let decoded = try decodeRGBA(result.pngData)

        // Assert
        for y in 0..<height {
            let transparentIdx = (y * width) * 4
            let opaqueIdx = (y * width + width - 1) * 4
            #expect(decoded.rgba[transparentIdx + 3] == 0, "row \(y) left should stay transparent")
            #expect(decoded.rgba[opaqueIdx + 3] == 255, "row \(y) right should stay opaque")
        }
    }

    @Test func preservesSemiTransparentAlphaApproximately() async throws {
        // Arrange: a single 50%-alpha color; decode comparison uses tolerance
        // because encoding round-trips through premultiplication.
        let image = try makeImage(width: 16, height: 16, colors: [[200, 80, 40, 128]])
        let quantizer = Quantizer()

        // Act
        let result = try await quantizer.quantize(cgImage: image, options: QuantizationOptions())
        let decoded = try decodeRGBA(result.pngData)

        // Assert: alpha survives; premultiplied RGB ≈ 200*128/255 etc.
        #expect(abs(Int(decoded.rgba[3]) - 128) <= 2)
        #expect(abs(Int(decoded.rgba[0]) - 100) <= 3)
        #expect(abs(Int(decoded.rgba[1]) - 40) <= 3)
        #expect(abs(Int(decoded.rgba[2]) - 20) <= 3)
    }

    // MARK: - Options

    @Test func ditheringProducesDecodablePNG() async throws {
        // Arrange
        let image = try makeImage(width: 32, height: 32, colors: [[255, 0, 0], [250, 5, 5], [245, 10, 10]])
        let quantizer = Quantizer()
        let options = QuantizationOptions(numberOfColors: 2, dithering: true)

        // Act
        let result = try await quantizer.quantize(cgImage: image, options: options)
        let decoded = try decodeRGBA(result.pngData)

        // Assert
        #expect(decoded.width == 32)
        #expect(uniqueColors(in: decoded.rgba).count <= 2)
    }

    @Test func quantizedPNGIsSmallerThanTruecolorSource() async throws {
        // Arrange: noisy image so the RGBA source PNG doesn't compress trivially
        let width = 128, height = 128
        var seed: UInt64 = 42
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            rgba[i * 4] = UInt8((seed >> 33) & 0xFF)
            rgba[i * 4 + 1] = UInt8((seed >> 41) & 0xFF)
            rgba[i * 4 + 2] = UInt8((seed >> 49) & 0xFF)
            rgba[i * 4 + 3] = 255
        }
        let image = try makeTestCGImage(width: width, height: height, rgba: rgba)
        let sourcePNG = try encodeTruecolorPNG(image)
        let quantizer = Quantizer()
        let options = QuantizationOptions(numberOfColors: 256)

        // Act
        let result = try await quantizer.quantize(cgImage: image, options: options)

        // Assert
        #expect(result.pngData.count < sourcePNG.count)
    }
}
