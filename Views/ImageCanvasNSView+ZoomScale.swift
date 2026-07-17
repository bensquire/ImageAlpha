import AppKit

// MARK: - Zoom value accessors (non-linear slider mapping)

extension ImageCanvasNSView {

    static func sliderToZoom(_ sliderValue: CGFloat) -> CGFloat {
        sliderValue < 3.0 ? 1.0 / (4.0 - sliderValue) : sliderValue - 2.0
    }

    static func zoomToSlider(_ z: CGFloat) -> CGFloat {
        z < 1.0 ? max(0, 4.0 - 1.0 / z) : z + 2.0
    }

    static func zoomDisplayString(_ z: CGFloat) -> String {
        if z >= 1.0 {
            let rounded = (z * 10).rounded() / 10
            if rounded == rounded.rounded() {
                return "\(Int(rounded))\u{00D7}"
            }
            return String(format: "%.1f\u{00D7}", rounded)
        }
        let fractions = ["\u{00BD}\u{00D7}", "\u{2153}\u{00D7}", "\u{00BC}\u{00D7}"]
        let idx = min(2, max(0, Int(round(1.0 / z)) - 2))
        return fractions[idx]
    }

    // MARK: - Image scale helpers

    private func getScale(of image: NSImage) -> NSSize {
        guard let rep = image.representations.first else { return .zero }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        return NSSize(width: CGFloat(rep.pixelsWide) / imageSize.width, height: CGFloat(rep.pixelsHigh) / imageSize.height)
    }

    private func setScale(_ scale: NSSize, of image: NSImage) {
        guard let rep = image.representations.first, scale.width > 0, scale.height > 0 else { return }
        image.size = NSSize(width: CGFloat(rep.pixelsWide) / scale.width, height: CGFloat(rep.pixelsHigh) / scale.height)
    }

    /// Copies the original's point↔pixel scale onto the display image so both
    /// render at identical size.
    func syncImageScale() {
        guard let original = originalImage, let display = displayImage else { return }
        let scale = getScale(of: original)
        setScale(scale, of: display)
    }
}
