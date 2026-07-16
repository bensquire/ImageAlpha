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
}
