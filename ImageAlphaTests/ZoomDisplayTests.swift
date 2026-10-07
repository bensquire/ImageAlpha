import Foundation
import Testing

@testable import ImageAlpha

struct ZoomDisplayTests {

    @Test func wholeNumberZoomShowsInteger() {
        // Act
        let display = ImageCanvasNSView.zoomDisplayString(2.0)

        // Assert
        #expect(display == "2×")
    }

    @Test func fractionalZoomShowsOneDecimal() {
        // Act
        let display = ImageCanvasNSView.zoomDisplayString(1.5)

        // Assert
        #expect(display == "1.5×")
    }

    @Test func nearlyWholeZoomRoundsToInteger() {
        // Act
        let display = ImageCanvasNSView.zoomDisplayString(2.98)

        // Assert
        #expect(display == "3×")
    }

    @Test(arguments: [(0.5, "½×"), (1.0 / 3.0, "⅓×"), (0.25, "¼×")])
    func zoomBelowOneShowsAFraction(zoom: Double, shown: String) {
        // Act
        let display = ImageCanvasNSView.zoomDisplayString(CGFloat(zoom))

        // Assert
        #expect(display == shown)
    }
}
