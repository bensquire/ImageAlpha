import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import ImageAlpha

/// Decoded PNG as straight-alpha RGBA bytes, for round-trip assertions.
struct DecodedImage {
    let width: Int
    let height: Int
    let rgba: [UInt8]

    /// Only exact for pixels whose alpha is 0 or 255 (premultiplication is
    /// identity there); semi-transparent pixels come back premultiplied.
    init?(pngData: Data) {
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        width = image.width
        height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { return nil }
        rgba = pixels
    }
}

/// Builds a straight-alpha RGBA CGImage from raw bytes.
func makeTestCGImage(width: Int, height: Int, rgba: [UInt8]) throws -> CGImage {
    let provider = try #require(CGDataProvider(data: Data(rgba) as CFData))
    return try #require(CGImage(
        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    ))
}

/// Encodes via ImageIO (truecolor PNG) — the size baseline indexed output must beat.
func encodeTruecolorPNG(_ image: CGImage) throws -> Data {
    let data = NSMutableData()
    let dest = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
}

struct IndexedPNGEncoderTests {

    typealias Entry = IndexedPNGEncoder.PaletteEntry

    // MARK: - Helpers

    private func decodeRGBA(_ pngData: Data) throws -> DecodedImage {
        try #require(DecodedImage(pngData: pngData))
    }

    /// PNG IHDR layout: byte 24 is bit depth, byte 25 is color type.
    private func ihdrBitDepth(_ png: Data) -> UInt8 { png[24] }
    private func ihdrColorType(_ png: Data) -> UInt8 { png[25] }

    private func containsChunk(_ png: Data, _ type: String) -> Bool {
        png.range(of: Data(type.utf8)) != nil
    }

    // MARK: - Compression effort

    @Test func maximumEffortDecodesIdenticallyAndIsNoLarger() throws {
        // Arrange: varied indices so the deflate streams are non-trivial
        let width = 64, height = 64
        var palette: [Entry] = []
        for i in 0..<64 {
            palette.append(Entry(red: UInt8(i * 4), green: UInt8(255 - i * 2), blue: UInt8(i), alpha: 255))
        }
        var pixels = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            pixels[i] = UInt8((i * 7 + i / width) % 64)
        }

        // Act
        let fast = try #require(IndexedPNGEncoder.encode(
            width: width, height: height, palette: palette, pixels: pixels, effort: .fast
        ))
        let maximum = try #require(IndexedPNGEncoder.encode(
            width: width, height: height, palette: palette, pixels: pixels, effort: .maximum
        ))

        // Assert: same pixels out of both, smaller-or-equal file from maximum
        let fastDecoded = try decodeRGBA(fast)
        let maxDecoded = try decodeRGBA(maximum)
        #expect(fastDecoded.rgba == maxDecoded.rgba)
        #expect(maximum.count <= fast.count)
    }

    // MARK: - Bit depth selection

    @Test func bitDepthIs1ForTwoColorPalette() {
        // Arrange
        let paletteCount = 2

        // Act
        let depth = IndexedPNGEncoder.bitDepth(forPaletteCount: paletteCount)

        // Assert
        #expect(depth == 1)
    }

    @Test func bitDepthIs2ForThreeColorPalette() {
        // Arrange
        let paletteCount = 3

        // Act
        let depth = IndexedPNGEncoder.bitDepth(forPaletteCount: paletteCount)

        // Assert
        #expect(depth == 2)
    }

    @Test func bitDepthIs4ForSixteenColorPalette() {
        // Arrange
        let paletteCount = 16

        // Act
        let depth = IndexedPNGEncoder.bitDepth(forPaletteCount: paletteCount)

        // Assert
        #expect(depth == 4)
    }

    @Test func bitDepthIs8ForSeventeenColorPalette() {
        // Arrange
        let paletteCount = 17

        // Act
        let depth = IndexedPNGEncoder.bitDepth(forPaletteCount: paletteCount)

        // Assert
        #expect(depth == 8)
    }

    @Test func bitDepthIs8For256ColorPalette() {
        // Arrange
        let paletteCount = 256

        // Act
        let depth = IndexedPNGEncoder.bitDepth(forPaletteCount: paletteCount)

        // Assert
        #expect(depth == 8)
    }

    // MARK: - Header

    @Test func encodesIndexedColorType() throws {
        // Arrange
        let palette = [Entry(red: 255, green: 0, blue: 0, alpha: 255), Entry(red: 0, green: 255, blue: 0, alpha: 255)]
        let pixels: [UInt8] = [0, 1, 1, 0]

        // Act
        let png = try #require(IndexedPNGEncoder.encode(width: 2, height: 2, palette: palette, pixels: pixels))

        // Assert
        #expect(ihdrColorType(png) == 3)
        #expect(ihdrBitDepth(png) == 1)
    }

    // MARK: - Round trips

    @Test func roundTripsOpaquePixels() throws {
        // Arrange
        let palette = [
            Entry(red: 255, green: 0, blue: 0, alpha: 255),
            Entry(red: 0, green: 255, blue: 0, alpha: 255),
            Entry(red: 0, green: 0, blue: 255, alpha: 255),
            Entry(red: 17, green: 34, blue: 51, alpha: 255),
        ]
        let width = 5, height = 3
        let pixels: [UInt8] = (0..<(width * height)).map { UInt8($0 % 4) }

        // Act
        let png = try #require(IndexedPNGEncoder.encode(width: width, height: height, palette: palette, pixels: pixels))
        let decoded = try decodeRGBA(png)

        // Assert
        #expect(decoded.width == width)
        #expect(decoded.height == height)
        for i in 0..<(width * height) {
            let expected = palette[Int(pixels[i])]
            #expect(decoded.rgba[i * 4 + 0] == expected.red)
            #expect(decoded.rgba[i * 4 + 1] == expected.green)
            #expect(decoded.rgba[i * 4 + 2] == expected.blue)
            #expect(decoded.rgba[i * 4 + 3] == 255)
        }
    }

    @Test func roundTripsFullyTransparentPixels() throws {
        // Arrange
        let palette = [
            Entry(red: 0, green: 0, blue: 0, alpha: 0),
            Entry(red: 200, green: 100, blue: 50, alpha: 255),
        ]
        let pixels: [UInt8] = [0, 1, 0, 1]

        // Act
        let png = try #require(IndexedPNGEncoder.encode(width: 2, height: 2, palette: palette, pixels: pixels))
        let decoded = try decodeRGBA(png)

        // Assert
        #expect(decoded.rgba[3] == 0)   // pixel 0 alpha
        #expect(decoded.rgba[7] == 255) // pixel 1 alpha
        #expect(decoded.rgba[4] == 200)
        #expect(decoded.rgba[5] == 100)
        #expect(decoded.rgba[6] == 50)
    }

    @Test func roundTripsNonByteAlignedRowWidths() throws {
        // Arrange: 3 pixels/row at 1-bit depth exercises row bit padding
        let palette = [
            Entry(red: 0, green: 0, blue: 0, alpha: 255),
            Entry(red: 255, green: 255, blue: 255, alpha: 255),
        ]
        let width = 3, height = 3
        let pixels: [UInt8] = [1, 0, 1, 0, 1, 0, 1, 1, 0]

        // Act
        let png = try #require(IndexedPNGEncoder.encode(width: width, height: height, palette: palette, pixels: pixels))
        let decoded = try decodeRGBA(png)

        // Assert
        for i in 0..<(width * height) {
            let expected: UInt8 = pixels[i] == 1 ? 255 : 0
            #expect(decoded.rgba[i * 4] == expected, "pixel \(i)")
        }
    }

    @Test func roundTrips256ColorPalette() throws {
        // Arrange
        let palette = (0..<256).map { Entry(red: UInt8($0), green: UInt8(255 - $0), blue: UInt8($0 / 2), alpha: 255) }
        let width = 16, height = 16
        let pixels: [UInt8] = (0..<256).map { UInt8($0) }

        // Act
        let png = try #require(IndexedPNGEncoder.encode(width: width, height: height, palette: palette, pixels: pixels))
        let decoded = try decodeRGBA(png)

        // Assert
        for i in 0..<(width * height) {
            #expect(decoded.rgba[i * 4 + 0] == palette[i].red)
            #expect(decoded.rgba[i * 4 + 1] == palette[i].green)
            #expect(decoded.rgba[i * 4 + 2] == palette[i].blue)
        }
    }

    // MARK: - tRNS chunk

    @Test func omitsTRNSChunkWhenPaletteFullyOpaque() throws {
        // Arrange
        let palette = [Entry(red: 1, green: 2, blue: 3, alpha: 255), Entry(red: 4, green: 5, blue: 6, alpha: 255)]

        // Act
        let png = try #require(IndexedPNGEncoder.encode(width: 2, height: 1, palette: palette, pixels: [0, 1]))

        // Assert
        #expect(!containsChunk(png, "tRNS"))
    }

    @Test func includesTRNSChunkWhenPaletteHasTransparency() throws {
        // Arrange
        let palette = [Entry(red: 1, green: 2, blue: 3, alpha: 0), Entry(red: 4, green: 5, blue: 6, alpha: 255)]

        // Act
        let png = try #require(IndexedPNGEncoder.encode(width: 2, height: 1, palette: palette, pixels: [0, 1]))

        // Assert
        #expect(containsChunk(png, "tRNS"))
    }

    // MARK: - Size

    @Test func indexedOutputIsSmallerThanImageIORGBAEncoding() throws {
        // Arrange: pseudo-random 16-color 64x64 image (seeded LCG, deterministic)
        var palette: [Entry] = []
        for i in 0..<16 {
            let red = UInt8(i * 16)
            let green = UInt8(i * 7 % 256)
            let blue = UInt8(i * 13 % 256)
            palette.append(Entry(red: red, green: green, blue: blue, alpha: 255))
        }
        let width = 64, height = 64
        var seed: UInt64 = 0x2545_F491_4F6C_DD1D
        let pixels: [UInt8] = (0..<(width * height)).map { _ in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return UInt8((seed >> 33) % 16)
        }
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            let entry = palette[Int(pixels[i])]
            rgba[i * 4] = entry.red; rgba[i * 4 + 1] = entry.green; rgba[i * 4 + 2] = entry.blue; rgba[i * 4 + 3] = 255
        }
        let cgImage = try makeTestCGImage(width: width, height: height, rgba: rgba)
        let imageIOData = try encodeTruecolorPNG(cgImage)

        // Act
        let indexed = try #require(IndexedPNGEncoder.encode(width: width, height: height, palette: palette, pixels: pixels))

        // Assert
        #expect(indexed.count < imageIOData.count)
    }

    // MARK: - Invalid input

    @Test func returnsNilForEmptyPalette() {
        // Act
        let png = IndexedPNGEncoder.encode(width: 1, height: 1, palette: [], pixels: [0])

        // Assert
        #expect(png == nil)
    }

    @Test func returnsNilForMismatchedPixelCount() {
        // Arrange
        let palette = [Entry(red: 0, green: 0, blue: 0, alpha: 255)]

        // Act
        let png = IndexedPNGEncoder.encode(width: 2, height: 2, palette: palette, pixels: [0, 0, 0])

        // Assert
        #expect(png == nil)
    }

    @Test func returnsNilForOutOfRangePaletteIndex() {
        // Arrange
        let palette = [Entry(red: 0, green: 0, blue: 0, alpha: 255)]

        // Act
        let png = IndexedPNGEncoder.encode(width: 1, height: 1, palette: palette, pixels: [1])

        // Assert
        #expect(png == nil)
    }

    @Test func returnsNilForZeroDimensions() {
        // Arrange
        let palette = [Entry(red: 0, green: 0, blue: 0, alpha: 255)]

        // Act
        let png = IndexedPNGEncoder.encode(width: 0, height: 0, palette: palette, pixels: [])

        // Assert
        #expect(png == nil)
    }

    // MARK: - Checksums

    @Test func adler32MatchesKnownVector() {
        // Arrange: "Wikipedia" has a documented Adler-32 of 0x11E60398
        let bytes = [UInt8]("Wikipedia".utf8)

        // Act
        let checksum = IndexedPNGEncoder.adler32(bytes)

        // Assert
        #expect(checksum == 0x11E6_0398)
    }

    @Test func crc32MatchesKnownVector() {
        // Arrange: "123456789" has a documented CRC-32 of 0xCBF43926
        let data = Data("123456789".utf8)

        // Act
        let checksum = IndexedPNGEncoder.crc32(data)

        // Assert
        #expect(checksum == 0xCBF4_3926)
    }
}
