import AppKit
import Combine
import os

@MainActor
class DocumentModel: ObservableObject {
    @Published var sourceImage: NSImage?
    @Published var sourceCGImage: CGImage?
    @Published var numberOfColors: Int = 256
    @Published var dithering: Bool = false
    @Published var speed: Int = 3
    @Published var showOriginal: Bool = false { didSet { if showOriginal { compareMode = false } } }
    @Published var quantizedImage: NSImage?
    @Published var quantizedPNGData: Data?
    @Published var compareMode: Bool = false { didSet { if compareMode { showOriginal = false } } }
    @Published var isBusy: Bool = false
    @Published var statusMessage: String = "To get started, drop PNG image onto main area on the right"
    @Published var selectedBackground: BackgroundStyle = .checkerboard
    @Published var sourceFileSize: Int?
    @Published var sourceURL: URL?
    @Published var sourceColorCount: Int?

    /// Called when the user changes a quantization parameter while an image
    /// is loaded, so the owning document can mark itself edited.
    var didChangeParameters: (() -> Void)?

    private static let logger = Logger(subsystem: "net.pornel.ImageAlpha", category: "DocumentModel")

    private let quantizer = Quantizer()
    private var quantizationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var sourceFileData: Data?
    /// Incremented on every load; async work captures the current value and
    /// discards its result if another image was loaded in the meantime.
    private var loadGeneration = 0

    init() {
        if let dithered = Preferences.dithering {
            self.dithering = dithered
        }
        self.speed = Preferences.speed

        Publishers.CombineLatest3($numberOfColors, $dithering, $speed)
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
        sourceFileSize = sourceFileData?.count

        // Get CGImage from NSImage
        var rect = NSRect(origin: .zero, size: image.size)
        sourceCGImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        guard sourceCGImage != nil else {
            Self.logger.error("loadImage: cgImage failed for \(url.path, privacy: .public)")
            return false
        }

        sourceColorCount = nil
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
        sourceFileSize = data.count
        updateStatus()
    }

    func requestQuantization() {
        guard let cgImage = sourceCGImage else { return }

        // If numberOfColors > 256, show original (no quantization needed)
        if numberOfColors > 256 {
            quantizedPNGData = sourceFileData
            quantizedImage = sourceImage
            updateStatus()
            return
        }

        // Cancel previous quantization
        quantizationTask?.cancel()
        isBusy = true

        quantizationTask = Task {
            do {
                let options = QuantizationOptions(
                    numberOfColors: numberOfColors,
                    dithering: dithering,
                    speed: speed
                )
                let result = try await quantizer.quantize(cgImage: cgImage, options: options)

                guard !Task.isCancelled else { return }

                self.quantizedImage = result.image
                self.quantizedPNGData = result.pngData
                self.isBusy = false
                self.updateStatus()
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

    private func updateStatus() {
        guard quantizedPNGData != nil else {
            statusMessage = sourceImage != nil ? "Processing..." : "To get started, drop PNG image onto main area on the right"
            return
        }

        statusMessage = Self.formatStatus(
            quantizedSize: quantizedPNGData!.count,
            sourceSize: sourceFileSize,
            sourceColorCount: sourceColorCount,
            colorsDisplay: colorsDisplayString
        )
    }

    nonisolated static func formatStatus(
        quantizedSize: Int,
        sourceSize: Int?,
        sourceColorCount: Int?,
        colorsDisplay: String
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
        if numberOfColors > 256 { return "24-bit" }
        return "\(numberOfColors)"
    }
}
