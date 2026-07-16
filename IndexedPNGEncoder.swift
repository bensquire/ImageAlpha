import Foundation
import Compression

/// Encodes palette-quantized pixels as a color-type-3 (indexed) PNG, including
/// PLTE/tRNS chunks and minimal 1/2/4/8 bit depth. ImageIO can only write
/// truecolor PNGs, which would discard the size benefit of quantization.
enum IndexedPNGEncoder {

    struct PaletteEntry: Equatable {
        var red: UInt8
        var green: UInt8
        var blue: UInt8
        var alpha: UInt8
    }

    /// Smallest PNG-legal bit depth (1, 2, 4 or 8) that can index the palette.
    static func bitDepth(forPaletteCount count: Int) -> Int {
        switch count {
        case ...2: return 1
        case ...4: return 2
        case ...16: return 4
        default: return 8
        }
    }

    /// `pixels` are palette indices, one byte per pixel, row-major.
    /// Returns nil for structurally invalid input or if compression fails.
    static func encode(width: Int, height: Int, palette: [PaletteEntry], pixels: [UInt8]) -> Data? {
        guard width > 0, height > 0,
              (1...256).contains(palette.count),
              pixels.count == width * height,
              !pixels.contains(where: { Int($0) >= palette.count }) else {
            return nil
        }

        let depth = bitDepth(forPaletteCount: palette.count)
        let scanlines = packScanlines(pixels: pixels, width: width, height: height, bitDepth: depth)
        guard let idat = zlibCompress(scanlines) else { return nil }

        var ihdr = Data()
        ihdr.appendBigEndian(UInt32(width))
        ihdr.appendBigEndian(UInt32(height))
        ihdr.append(UInt8(depth))
        ihdr.append(3) // color type: indexed
        ihdr.append(0) // compression
        ihdr.append(0) // filter
        ihdr.append(0) // interlace

        var plte = Data(capacity: palette.count * 3)
        for entry in palette {
            plte.append(entry.red)
            plte.append(entry.green)
            plte.append(entry.blue)
        }

        var png = Data([137, 80, 78, 71, 13, 10, 26, 10])
        png.append(chunk("IHDR", ihdr))
        png.append(chunk("PLTE", plte))

        // tRNS holds palette alphas, truncated after the last non-opaque entry
        // and omitted entirely for fully opaque palettes.
        if let lastTransparent = palette.lastIndex(where: { $0.alpha < 255 }) {
            let trns = Data(palette[...lastTransparent].map(\.alpha))
            png.append(chunk("tRNS", trns))
        }

        png.append(chunk("IDAT", idat))
        png.append(chunk("IEND", Data()))
        return png
    }

    /// Prefixes each row with a None filter byte and packs indices big-endian
    /// (leftmost pixel in the most significant bits), rows padded to whole bytes.
    static func packScanlines(pixels: [UInt8], width: Int, height: Int, bitDepth: Int) -> Data {
        let pixelsPerByte = 8 / bitDepth
        let rowBytes = (width + pixelsPerByte - 1) / pixelsPerByte
        var out = Data(capacity: (rowBytes + 1) * height)

        for row in 0..<height {
            out.append(0) // filter: None
            var byte: UInt8 = 0
            var bitsUsed = 0
            for col in 0..<width {
                byte = (byte << bitDepth) | pixels[row * width + col]
                bitsUsed += bitDepth
                if bitsUsed == 8 {
                    out.append(byte)
                    byte = 0
                    bitsUsed = 0
                }
            }
            if bitsUsed > 0 {
                out.append(byte << (8 - bitsUsed))
            }
        }
        return out
    }

    /// Raw DEFLATE from the Compression framework wrapped in a zlib stream
    /// (header + Adler-32 trailer), as PNG's IDAT requires.
    static func zlibCompress(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        let source = [UInt8](data)
        let capacity = source.count + source.count / 4 + 256
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { destination.deallocate() }

        let written = compression_encode_buffer(
            destination, capacity,
            source, source.count,
            nil, COMPRESSION_ZLIB
        )
        guard written > 0 else { return nil }

        var out = Data([0x78, 0x9C])
        out.append(destination, count: written)
        out.appendBigEndian(adler32(source))
        return out
    }

    static func adler32(_ bytes: [UInt8]) -> UInt32 {
        let modAdler: UInt32 = 65521
        var low: UInt32 = 1
        var high: UInt32 = 0
        for byte in bytes {
            low = (low &+ UInt32(byte)) % modAdler
            high = (high &+ low) % modAdler
        }
        return (high << 16) | low
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var crc = UInt32(index)
        for _ in 0..<8 {
            crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
        }
        return crc
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static func chunk(_ type: String, _ payload: Data) -> Data {
        var out = Data()
        out.appendBigEndian(UInt32(payload.count))
        var typed = Data(type.utf8)
        typed.append(payload)
        out.append(typed)
        out.appendBigEndian(crc32(typed))
        return out
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
}
