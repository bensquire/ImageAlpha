import AppKit
import Combine

@MainActor
class DocumentModel: ObservableObject {
    @Published var sourceImage: NSImage?
    @Published var sourceCGImage: CGImage?
    @Published var numberOfColors: Int = 256
    @Published var dithering: Bool = false
    @Published var ieMode: Bool = false
    @Published var speed: Int = 3
    @Published var showOriginal: Bool = false
    @Published var quantizedImage: NSImage?
    @Published var quantizedPNGData: Data?
    @Published var isBusy: Bool = false
    @Published var statusMessage: String = "To get started, drop PNG image onto main area on the right"
    @Published var selectedBackground: BackgroundStyle = .checkerboard
    @Published var sourceFileSize: Int?
    @Published var sourceURL: URL?
    @Published var sourceColorCount: Int?

    private let quantizer = Quantizer()
    private var quantizationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let dithered = UserDefaults.standard.object(forKey: "dithered")
        if let dithered = dithered as? Bool {
            self.dithering = dithered
        }

        let speed = UserDefaults.standard.integer(forKey: "speed")
        if speed >= 1 && speed <= 10 {
            self.speed = speed
        }

        Publishers.CombineLatest4($numberOfColors, $dithering, $ieMode, $speed)
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.requestQuantization()
            }
            .store(in: &cancellables)
    }

    @discardableResult
    func loadImage(from url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url) else { NSLog("loadImage: NSImage failed for %@", url.path); return false }
        NSLog("loadImage: loaded %@ size=%@", url.lastPathComponent, NSStringFromSize(image.size))
        sourceURL = url
        sourceImage = image

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
            sourceFileSize = size
        }

        // Get CGImage from NSImage
        var rect = NSRect(origin: .zero, size: image.size)
        sourceCGImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        guard sourceCGImage != nil else { NSLog("loadImage: cgImage failed for %@", url.path); return false }

        sourceColorCount = nil
        if let cg = sourceCGImage {
            Task.detached { [weak self] in
                let count = Self.countUniqueColors(in: cg)
                await MainActor.run {
                    self?.sourceColorCount = count
                    self?.updateStatus()
                }
            }
        }

        requestQuantization()
        return true
    }

    func requestQuantization() {
        guard let cgImage = sourceCGImage else { NSLog("requestQuantization: no sourceCGImage"); return }

        // If numberOfColors > 256, show original (no quantization needed)
        if numberOfColors > 256 {
            if let url = sourceURL {
                quantizedPNGData = try? Data(contentsOf: url)
            }
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
                    ieMode: ieMode,
                    speed: speed
                )
                NSLog("requestQuantization: calling quantizer colors=%d dither=%d", numberOfColors, dithering ? 1 : 0)
                let result = try await quantizer.quantize(cgImage: cgImage, options: options)

                guard !Task.isCancelled else { NSLog("requestQuantization: cancelled"); return }

                NSLog("requestQuantization: got result, image=%@, pngData=%d bytes", result.image, result.pngData.count)
                self.quantizedImage = result.image
                self.quantizedPNGData = result.pngData
                self.isBusy = false
                self.updateStatus()
            } catch {
                guard !Task.isCancelled else { return }
                self.isBusy = false
                NSLog("requestQuantization: ERROR %@", error.localizedDescription)
                self.statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    func updateDithering() {
        let dithered = UserDefaults.standard.object(forKey: "dithered")
        if let dithered = dithered as? Bool {
            self.dithering = dithered
        } else {
            self.dithering = false
        }
    }

    func updateSpeed() {
        let savedSpeed = UserDefaults.standard.integer(forKey: "speed")
        self.speed = (savedSpeed >= 1 && savedSpeed <= 10) ? savedSpeed : 3
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
            originalParts.append("\(countString) colours")
        }
        if let sourceSize, sourceSize > 0 {
            let sizeString = fmt.string(from: NSNumber(value: sourceSize)) ?? "\(sourceSize)"
            originalParts.append("\(sizeString) bytes")
        }

        // Build "Quantized: …" part
        let quantizedSizeStr = fmt.string(from: NSNumber(value: quantizedSize)) ?? "\(quantizedSize)"
        var quantizedParts: [String] = []
        if sourceColorCount != nil {
            quantizedParts.append("\(colorsDisplay) colours")
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
