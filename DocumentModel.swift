import AppKit
import Combine
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
class DocumentModel: ObservableObject {
    @Published var sourceImage: NSImage?
    @Published var sourceCGImage: CGImage?
    @Published var numberOfColors: Int = 256
    @Published var quantizationMode: QuantizationMode = .colors
    @Published var targetQuality: Int = 80
    @Published var dithering: Bool = false
    @Published var speed: Int = 3
    @Published var showOriginal: Bool = false { didSet { if showOriginal { compareMode = false } } }
    @Published var quantizedImage: NSImage?
    @Published var quantizedPNGData: Data?
    @Published var compareMode: Bool = false { didSet { if compareMode { showOriginal = false } } }
    @Published var isBusy: Bool = false
    @Published var statusMessage: String = "To get started, drop PNG image onto main area on the right"
    @Published var selectedBackground: BackgroundStyle = .checkerboard
    @Published var sourceURL: URL?
    @Published var sourceColorCount: Int?
    /// Stats for the current result; nil until quantization completes or in
    /// 24-bit passthrough.
    @Published var resultStats: QuantizationStats?

    /// Called when the user changes a quantization parameter while an image
    /// is loaded, so the owning document can mark itself edited.
    var didChangeParameters: (() -> Void)?

    private static let logger = Logger(subsystem: "net.pornel.ImageAlpha", category: "DocumentModel")

    private let quantizer = Quantizer()
    private var quantizationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var sourceFileData: Data?
    /// Options that produced the current quantized output, so repeat requests
    /// with identical parameters are skipped.
    private var completedOptions: QuantizationOptions?
    /// Most recent results keyed by their options, capped at two entries, so
    /// toggling between modes restores either side without re-quantizing.
    private var recentResults: [(options: QuantizationOptions, result: QuantizationResult)] = []
    /// Incremented on every load; async work captures the current value and
    /// discards its result if another image was loaded in the meantime.
    private var loadGeneration = 0

    init() {
        if let dithered = Preferences.dithering {
            self.dithering = dithered
        }
        self.speed = Preferences.speed

        let paletteParams = Publishers.CombineLatest3($numberOfColors, $dithering, $speed)
        let qualityParams = Publishers.CombineLatest($quantizationMode, $targetQuality)
        Publishers.CombineLatest(paletteParams, qualityParams)
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.sourceImage != nil {
                    self.didChangeParameters?()
                }
                self.requestQuantization()
            }
            .store(in: &cancellables)
    }

    @discardableResult
    func loadImage(from url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url) else {
            Self.logger.error("loadImage: NSImage failed for \(url.path, privacy: .public)")
            return false
        }
        loadGeneration += 1
        sourceURL = url
        sourceImage = image

        sourceFileData = try? Data(contentsOf: url)

        // Get CGImage from NSImage
        var rect = NSRect(origin: .zero, size: image.size)
        sourceCGImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        guard sourceCGImage != nil else {
            Self.logger.error("loadImage: cgImage failed for \(url.path, privacy: .public)")
            return false
        }

        sourceColorCount = nil
        resultStats = nil
        completedOptions = nil
        recentResults.removeAll()
        if let cg = sourceCGImage {
            let generation = loadGeneration
            Task.detached { [weak self] in
                let count = Self.countUniqueColors(in: cg)
                await MainActor.run { [weak self] in
                    guard let self, self.loadGeneration == generation else { return }
                    self.sourceColorCount = count
                    self.updateStatus()
                }
            }
        }

        requestQuantization()
        return true
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
            quantizedPNGData = sourceFileData
            quantizedImage = sourceImage
            resultStats = nil
            completedOptions = nil
            isBusy = false
            updateStatus()
            return
        }

        // The current output already came from identical options — nothing to do.
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
                Self.logger.error("requestQuantization failed: \(error.localizedDescription, privacy: .public)")
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

    /// Publishes a quantization result and records it for reuse.
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
    }

    private func updateStatus() {
        guard quantizedPNGData != nil else {
            statusMessage = sourceImage != nil ? "Processing..." : "To get started, drop PNG image onto main area on the right"
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

    nonisolated static func formatStatus(
        quantizedSize: Int,
        sourceSize: Int?,
        sourceColorCount: Int?,
        colorsDisplay: String,
        quality: Int? = nil
    ) -> String {
        let fmt = decimalFormatter

        // Build "Original: …" part
        var originalParts: [String] = []
        if let count = sourceColorCount {
            let countString = fmt.string(from: NSNumber(value: count)) ?? "\(count)"
            originalParts.append("\(countString) colors")
        }
        if let sourceSize, sourceSize > 0 {
            let sizeString = fmt.string(from: NSNumber(value: sourceSize)) ?? "\(sourceSize)"
            originalParts.append("\(sizeString) bytes")
        }

        // Build "Quantized: …" part
        let quantizedSizeStr = fmt.string(from: NSNumber(value: quantizedSize)) ?? "\(quantizedSize)"
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
            return "Original: \(originalParts.joined(separator: ", ")). Quantized: \(quantizedParts.joined(separator: ", "))."
        }
    }

    private nonisolated static let decimalFormatter: NumberFormatter = {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.groupingSeparator = ","
        return fmt
    }()

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
              let data = context.data else {
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
