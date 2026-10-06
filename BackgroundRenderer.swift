import AppKit
import QuartzCore

enum BackgroundStyle: Hashable, Identifiable {
    case checkerboard
    case color(red: CGFloat, green: CGFloat, blue: CGFloat)
    case texture(name: String, ext: String)

    var id: String {
        switch self {
        case .checkerboard: return "checkerboard"
        case .color(let r, let g, let b): return "color-\(r)-\(g)-\(b)"
        case .texture(let name, let ext): return "texture-\(name).\(ext)"
        }
    }

    static let allBackgrounds: [BackgroundStyle] = [
        .checkerboard,
        .color(red: 1, green: 0, blue: 0),
        .color(red: 0, green: 1, blue: 0),
        .color(red: 0, green: 0, blue: 1),
        .texture(name: "white-gravel-128x128", ext: "png"),
        .texture(name: "clear-sea-water-128x128", ext: "png"),
        .texture(name: "green-grass-128x128", ext: "png"),
        .texture(name: "dark-smooth-stone-128x128", ext: "png"),
        .texture(name: "dark-wood-parquet-128x128", ext: "png"),
        .texture(name: "burning-hot-lava-128x128", ext: "png"),
        .texture(name: "dark-lucy-leaves-128x128", ext: "png"),
        .texture(name: "brick-wall-128x128", ext: "png"),
    ]

    /// What VoiceOver calls the style's button in the sidebar.
    var accessibilityName: String {
        switch self {
        case .checkerboard:
            return "Checkerboard"
        case .color(1, 0, 0):
            return "Red"
        case .color(0, 1, 0):
            return "Green"
        case .color(0, 0, 1):
            return "Blue"
        case .color:
            return "Solid color"
        case .texture(let name, _):
            // "white-gravel-128x128" → "White gravel"
            let words = name.replacingOccurrences(of: "-128x128", with: "").replacingOccurrences(of: "-", with: " ")
            return words.prefix(1).uppercased() + words.dropFirst()
        }
    }

    /// Read from the bundle once per texture, since the sidebar's thumbnails
    /// ask on every redraw. NSCache is safe to use from any thread.
    private static let textureCache = NSCache<NSString, NSImage>()

    /// The texture's image; nil for other styles or a missing file. The
    /// subdirectory form, because path(forResource:ofType:) "does not recurse
    /// through other subfolders". /documentation/foundation/bundle/path(forresource:oftype:)
    var textureImage: NSImage? {
        guard case .texture(let name, let ext) = self else { return nil }
        let key = "\(name).\(ext)" as NSString
        if let cached = Self.textureCache.object(forKey: key) { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "textures"),
            let image = NSImage(contentsOf: url)
        else { return nil }
        Self.textureCache.setObject(image, forKey: key)
        return image
    }
}

protocol BackgroundRendering {
    func makeLayer() -> CALayer
    var canMove: Bool { get }
    func moveBy(_ delta: NSSize)
}

class ColorBackground: BackgroundRendering {
    let cgColor: CGColor

    init(color: NSColor) {
        let srgbColor = color.usingColorSpace(.sRGB) ?? color
        self.cgColor = srgbColor.cgColor
    }

    init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.cgColor = CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    var canMove: Bool { false }

    func makeLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = cgColor
        return layer
    }

    func moveBy(_ delta: NSSize) {}
}

class PatternBackground: BackgroundRendering {
    private let cgImage: CGImage?
    private var offset: CGPoint = .zero
    private weak var currentLayer: CALayer?

    init(image: NSImage) {
        var rect = NSRect(origin: .zero, size: image.size)
        self.cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    var canMove: Bool { true }

    func makeLayer() -> CALayer {
        let layer = CALayer()
        layer.actions = [
            "backgroundColor": NSNull(),
            "contents": NSNull(),
            "bounds": NSNull(),
        ]
        currentLayer = layer
        updateTiling(on: layer)
        return layer
    }

    func moveBy(_ delta: NSSize) {
        offset.x += delta.width
        offset.y += delta.height
        if let layer = currentLayer {
            updateTiling(on: layer)
        }
    }

    private func updateTiling(on layer: CALayer) {
        guard let img = cgImage else { return }

        let width = CGFloat(img.width)
        let height = CGFloat(img.height)

        // Retain the CGImage for the pattern callback lifetime
        let retainedImage = Unmanaged<CGImage>.passRetained(img)

        var callbacks = CGPatternCallbacks(
            version: 0,
            drawPattern: { info, ctx in
                guard let info = info else { return }
                let image = Unmanaged<CGImage>.fromOpaque(info).takeUnretainedValue()
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
            },
            releaseInfo: { info in
                guard let info = info else { return }
                Unmanaged<CGImage>.fromOpaque(info).release()
            })

        let rawPtr = retainedImage.toOpaque()
        guard
            let pattern = CGPattern(
                info: rawPtr,
                bounds: CGRect(x: 0, y: 0, width: width, height: height),
                matrix: CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: offset.x, ty: offset.y),
                xStep: width,
                yStep: height,
                tiling: .constantSpacing,
                isColored: true,
                callbacks: &callbacks
            )
        else {
            retainedImage.release()
            return
        }

        guard let space = CGColorSpace(patternBaseSpace: nil) else { return }
        var alpha: CGFloat = 1.0
        guard let color = CGColor(patternSpace: space, pattern: pattern, components: &alpha) else { return }
        layer.backgroundColor = color
    }
}

class CheckerboardBackground: BackgroundRendering {
    // Light mode: white (1.0) + light gray (0.86) — classic Photoshop
    // Dark mode: dark gray (0.24) + slightly lighter (0.30)
    static func checkerLightWhite(isDark: Bool) -> CGFloat { isDark ? 0.30 : 1.0 }
    static func checkerDarkWhite(isDark: Bool) -> CGFloat { isDark ? 0.24 : 0.86 }

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static let checkerLight = NSColor(name: nil) { appearance in
        NSColor(white: checkerLightWhite(isDark: isDark(appearance)), alpha: 1)
    }
    static let checkerDark = NSColor(name: nil) { appearance in
        NSColor(white: checkerDarkWhite(isDark: isDark(appearance)), alpha: 1)
    }

    /// Fixed at creation rather than resolved from dynamic colours while
    /// drawing, when the thread's appearance needn't be the view's.
    /// /documentation/appkit/nsappearance/current
    private let isDark: Bool

    init(isDark: Bool) {
        self.isDark = isDark
    }

    var canMove: Bool { false }

    func makeLayer() -> CALayer {
        guard let checkerImage = createCheckerboardImage() else {
            let layer = CALayer()
            layer.backgroundColor = CGColor(gray: 0.8, alpha: 1)
            return layer
        }
        let bg = PatternBackground(image: checkerImage)
        return bg.makeLayer()
    }

    func moveBy(_ delta: NSSize) {}

    private func createCheckerboardImage() -> NSImage? {
        let size = 16
        let light = NSColor(white: Self.checkerLightWhite(isDark: isDark), alpha: 1)
        let dark = NSColor(white: Self.checkerDarkWhite(isDark: isDark), alpha: 1)
        return NSImage(size: NSSize(width: size * 2, height: size * 2), flipped: false) { rect in
            dark.setFill()
            rect.fill()
            light.setFill()
            NSRect(x: 0, y: 0, width: size, height: size).fill()
            NSRect(x: size, y: size, width: size, height: size).fill()
            return true
        }
    }
}

func makeBackgroundRenderer(for style: BackgroundStyle, isDark: Bool) -> BackgroundRendering {
    switch style {
    case .checkerboard:
        return CheckerboardBackground(isDark: isDark)
    case .color(let r, let g, let b):
        return ColorBackground(r: r, g: g, b: b)
    case .texture:
        if let image = style.textureImage {
            return PatternBackground(image: image)
        }
        return ColorBackground(r: 0.5, g: 0.5, b: 0.5)
    }
}
