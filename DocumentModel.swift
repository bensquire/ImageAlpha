import AppKit
import Observation
import os

enum QuantizationMode: String, CaseIterable {
    /// User picks a fixed palette size.
    case colors
    /// User picks a quality target; the smallest palette that reaches it wins.
    case quality
}

/// What the last completed quantization actually produced.
struct QuantizationStats: Equatable {
    var paletteCount: Int
    /// libimagequant's 0–100 quality estimate; nil when it doesn't compute one.
    var quality: Int?
}

@MainActor
@Observable
class DocumentModel {
    var sourceImage: NSImage?
    var sourceCGImage: CGImage?
    // The quantization parameters. Changing one marks the document edited and
    // quantizes again, after a 50 ms pause so scrubbing a slider runs once.
    var numberOfColors: Int = 256 { didSet { parametersChanged() } }
    var quantizationMode: QuantizationMode = .colors { didSet { parametersChanged() } }
    var targetQuality: Int = 80 { didSet { parametersChanged() } }
    var dithering: Bool = Preferences.dithering ?? false { didSet { parametersChanged() } }
    var speed: Int = Preferences.speed { didSet { parametersChanged() } }
    var showOriginal: Bool = false { didSet { if showOriginal { compareMode = false } } }
    var quantizedImage: NSImage?
    var quantizedPNGData: Data?
    var compareMode: Bool = false { didSet { if compareMode { showOriginal = false } } }
    var isBusy: Bool = false
    var statusMessage: String = "To get started, drop PNG image onto main area on the right"
    var selectedBackground: BackgroundStyle = .checkerboard
    var sourceURL: URL?
    var sourceColorCount: Int?
    /// Stats for the current result; nil until quantization completes or in
    /// 24-bit passthrough.
    var resultStats: QuantizationStats?

    /// Called when the user changes a quantization parameter while an image
    /// is loaded, so the owning document can mark itself edited.
    @ObservationIgnored var didChangeParameters: (() -> Void)?

    private static let logger = Logger(subsystem: "net.pornel.ImageAlpha", category: "DocumentModel")

    private let quantizer = Quantizer()
    @ObservationIgnored private var parameterTask: Task<Void, Never>?
    @ObservationIgnored private var quantizationTask: Task<Void, Never>?
    /// Debounced background maximum-effort re-encode of the current result.
    /// Purely a preview-size nicety: saving calls finalPNGData() directly.
    @ObservationIgnored private var refinementTask: Task<Void, Never>?
    @ObservationIgnored private var sourceFileData: Data?
    /// Options that produced the current quantized output, so repeat requests
    /// with identical parameters are skipped.
    @ObservationIgnored private var completedOptions: QuantizationOptions?
    /// Most recent results keyed by their options, capped at two entries, so
    /// toggling between modes restores either side without re-quantizing.
    @ObservationIgnored private var recentResults:
        [(options: QuantizationOptions, result: QuantizationResult)] = []
    /// Incremented on every load; async work captures the current value and
    /// discards its result if another image was loaded in the meantime.
    @ObservationIgnored private var loadGeneration = 0

    /// Whether a change is an edit is decided when it happens, not when the
    /// debounce ends, by which time a file being opened may have loaded its image.
    private func parametersChanged() {
        let isEdit = sourceImage != nil
        parameterTask?.cancel()
        parameterTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard let self, !Task.isCancelled else { return }
            if isEdit {
                self.didChangeParameters?()
            }
            self.requestQuantization()
        }
    }

    /// Throws, leaving the current image in place, when the file can't be
    /// read or isn't an image.
    func loadImage(from url: URL) throws {
        let data = try Data(contentsOf: url)
        // A nil rect means the image's own size (NSImage.h).
        guard let image = NSImage(data: data),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSURLErrorKey: url])
        }

        loadGeneration += 1
        sourceURL = url
        sourceImage = image
        sourceFileData = data
        sourceCGImage = cgImage

        sourceColorCount = nil
        resultStats = nil
        completedOptions = nil
        recentResults.removeAll()
        let generation = loadGeneration
        Task.detached { [weak self] in
            let count = Self.countUniqueColors(in: cgImage)
            await MainActor.run { [weak self] in
                guard let self, self.loadGeneration == generation else { return }
                self.sourceColorCount = count
                self.updateStatus()
            }
        }

        requestQuantization()
    }

    /// Refresh source stats after the quantized output overwrote the original file.
    func noteSaved(to url: URL) {
        guard url == sourceURL, let data = quantizedPNGData else { return }
        sourceFileData = data
        updateStatus()
    }

    /// How the current parameters translate into quantizer options; nil means
    /// 24-bit passthrough (no quantization). Owns all mode interpretation.
    var effectiveOptions: QuantizationOptions? {
        if quantizationMode == .colors && numberOfColors > 256 { return nil }
        return QuantizationOptions(
            numberOfColors: quantizationMode == .quality ? 256 : numberOfColors,
            dithering: dithering,
            speed: speed,
            qualityTarget: quantizationMode == .quality ? targetQuality : nil
        )
    }

    func requestQuantization() {
        guard let cgImage = sourceCGImage else { return }
        quantizationTask?.cancel()

        guard let options = effectiveOptions else {
            // 24-bit passthrough: show the original file as-is
            refinementTask?.cancel()
            quantizedPNGData = sourceFileData
            quantizedImage = sourceImage
            resultStats = nil
            completedOptions = nil
            isBusy = false
            updateStatus()
            return
        }

        // The current output already came from identical options — nothing to
        // do, and any in-flight refinement of it stays valid.
        if options == completedOptions && quantizedPNGData != nil {
            isBusy = false
            return
        }

        // Toggling modes revisits recently used options; restore that result.
        if let cached = recentResults.first(where: { $0.options == options })?.result {
            apply(cached, for: options)
            isBusy = false
            return
        }

        refinementTask?.cancel()
        isBusy = true
        quantizationTask = Task {
            do {
                let result = try await quantizer.quantize(cgImage: cgImage, options: options)

                guard !Task.isCancelled else { return }

                self.apply(result, for: options)
                self.isBusy = false
            } catch {
                guard !Task.isCancelled else { return }
                self.isBusy = false
                Self.logger.error(
                    "requestQuantization failed: \(error.localizedDescription, privacy: .public)")
                self.statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    func updateDithering() {
        self.dithering = Preferences.dithering ?? false
    }

    func updateSpeed() {
        self.speed = Preferences.speed
    }

    /// Publishes a quantization result and records it for reuse. Results that
    /// still carry their bitmap get a debounced maximum-effort re-encode.
    private func apply(_ result: QuantizationResult, for options: QuantizationOptions) {
        quantizedImage = result.image
        quantizedPNGData = result.pngData
        resultStats = QuantizationStats(paletteCount: result.paletteCount, quality: result.quality)
        completedOptions = options
        recentResults.removeAll { $0.options == options }
        recentResults.insert((options, result), at: 0)
        if recentResults.count > 2 {
            recentResults.removeLast()
        }
        updateStatus()
        if result.bitmap != nil {
            refinementTask?.cancel()
            refinementTask = Task { [weak self] in
                // Let slider scrubbing settle before spending seconds on deflate.
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await self?.refineCurrentResult()
            }
        }
    }

    /// Re-encodes the current result with maximum-effort deflate off the main
    /// actor and publishes the smaller file; no-op once refined. The fast
    /// encode is an upper bound, so the shown size only ever improves.
    private func refineCurrentResult() async {
        guard let options = completedOptions,
            let bitmap = recentResults.first(where: { $0.options == options })?.result.bitmap
        else { return }

        let data = await Task.detached(priority: .utility) {
            IndexedPNGEncoder.encode(bitmap, effort: .maximum)
        }.value

        // Re-check: parameters may have moved on while encoding.
        guard completedOptions == options,
            let index = recentResults.firstIndex(where: { $0.options == options })
        else { return }
        recentResults[index].result.bitmap = nil
        // Level 9 should never lose, but keep the smaller file if it does.
        if let data, data.count < recentResults[index].result.pngData.count {
            recentResults[index].result.pngData = data
            quantizedPNGData = data
            updateStatus()
        }
    }

    /// The best encode of the current result, produced on demand: skips the
    /// refinement debounce and re-encodes immediately if needed. Saves call
    /// this so the persisted file never depends on background-task timing.
    func finalPNGData() async -> Data? {
        refinementTask?.cancel()
        await refineCurrentResult()
        return quantizedPNGData
    }

    private func updateStatus() {
        guard quantizedPNGData != nil else {
            statusMessage =
                sourceImage != nil
                ? "Processing..." : "To get started, drop PNG image onto main area on the right"
            return
        }

        statusMessage = Self.formatStatus(
            quantizedSize: quantizedPNGData!.count,
            sourceSize: sourceFileData?.count,
            sourceColorCount: sourceColorCount,
            colorsDisplay: colorsDisplayString,
            quality: resultStats?.quality
        )
    }

    /// Numbers follow `locale`, the user's own by default, rather than a
    /// fixed "," separator.
    nonisolated static func formatStatus(
        quantizedSize: Int,
        sourceSize: Int?,
        sourceColorCount: Int?,
        colorsDisplay: String,
        quality: Int? = nil,
        locale: Locale = .current
    ) -> String {
        func number(_ value: Int) -> String { value.formatted(.number.locale(locale)) }

        // Build "Original: …" part
        var originalParts: [String] = []
        if let count = sourceColorCount {
            let countString = number(count)
            originalParts.append("\(countString) colors")
        }
        if let sourceSize, sourceSize > 0 {
            let sizeString = number(sourceSize)
            originalParts.append("\(sizeString) bytes")
        }

        // Build "Quantized: …" part
        let quantizedSizeStr = number(quantizedSize)
        var quantizedParts: [String] = []
        if sourceColorCount != nil {
            quantizedParts.append("\(colorsDisplay) colors")
        }
        var bytesStr = "\(quantizedSizeStr) bytes"
        if let sourceSize, sourceSize > 0 {
            let pct = abs(quantizedSize - sourceSize) * 100 / sourceSize
            let label = quantizedSize <= sourceSize ? "smaller" : "bigger"
            bytesStr += " (\(pct)% \(label))"
        }
        quantizedParts.append(bytesStr)
        if let quality {
            quantizedParts.append("quality: \(quality)%")
        }

        if sourceColorCount == nil && originalParts.isEmpty {
            return "Quantized: \(quantizedParts.joined(separator: ", "))."
        } else if sourceColorCount == nil {
            return "Original: \(originalParts.joined(separator: ", ")). Quantized: ..."
        } else {
            return
                "Original: \(originalParts.joined(separator: ", ")). Quantized: \(quantizedParts.joined(separator: ", "))."
        }
    }

    private nonisolated static func countUniqueColors(in cgImage: CGImage) -> Int {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let data = context.data
        else {
            return 0
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let pixelCount = totalBytes / bytesPerPixel
        let pixels = data.bindMemory(to: UInt32.self, capacity: pixelCount)
        let buffer = UnsafeBufferPointer(start: pixels, count: pixelCount)

        var unique = Set<UInt32>(minimumCapacity: min(pixelCount, 1 << 18))
        for pixel in buffer {
            unique.insert(pixel)
        }
        return unique.count
    }

    // Number of colors ↔ bit depth slider (log2 scale)
    var bitDepthSliderValue: Double {
        get {
            if numberOfColors > 256 { return 9 }
            if numberOfColors <= 2 { return 1 }
            return log2(Double(numberOfColors))
        }
        set {
            let roundedValue = Int(newValue.rounded())
            if roundedValue > 8 {
                numberOfColors = 257
            } else if roundedValue <= 1 {
                numberOfColors = 2
            } else {
                numberOfColors = Int(pow(2.0, Double(roundedValue)).rounded())
            }
        }
    }

    var colorsDisplayString: String {
        if quantizationMode == .quality {
            if let count = resultStats?.paletteCount { return "\(count)" }
            return "…"
        }
        if numberOfColors > 256 { return "24-bit" }
        return "\(numberOfColors)"
    }
}
