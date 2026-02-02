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

    func loadImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else { NSLog("loadImage: NSImage failed for %@", url.path); return }
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

        requestQuantization()
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
        let s = UserDefaults.standard.integer(forKey: "speed")
        self.speed = (s >= 1 && s <= 10) ? s : 3
    }

    private func updateStatus() {
        guard let data = quantizedPNGData else {
            statusMessage = sourceImage != nil ? "Processing..." : "To get started, drop PNG image onto main area on the right"
            return
        }
        if let sourceSize = sourceFileSize, sourceSize > 0 {
            let percent = 100 - data.count * 100 / sourceSize
            statusMessage = "Image size: \(data.count) bytes (saved \(percent)% of \(sourceSize) bytes)"
        } else {
            statusMessage = "Image size: \(data.count) bytes"
        }
    }

    // Number of colors ↔ bit depth slider (log2 scale)
    var bitDepthSliderValue: Double {
        get {
            if numberOfColors > 256 { return 9 }
            if numberOfColors <= 2 { return 1 }
            return log2(Double(numberOfColors))
        }
        set {
            let v = Int(newValue.rounded())
            if v > 8 {
                numberOfColors = 257
            } else if v <= 1 {
                numberOfColors = 2
            } else {
                numberOfColors = Int(pow(2.0, Double(v)).rounded())
            }
        }
    }

    var colorsDisplayString: String {
        if numberOfColors > 256 { return "2\u{00B2}\u{2074}" }
        return "\(numberOfColors)"
    }
}
