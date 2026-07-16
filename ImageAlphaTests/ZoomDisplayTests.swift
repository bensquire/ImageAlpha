import Testing
import Foundation
@testable import ImageAlpha

struct ZoomDisplayTests {

    @Test func wholeNumberZoomShowsInteger() {
        // Act
        let display = ImageCanvasNSView.zoomDisplayString(2.0)

        // Assert
        #expect(display == "2\u{00D7}")
    }

    @Test func fractionalZoomShowsOneDecimal() {
        // Act
        let display = ImageCanvasNSView.zoomDisplayString(1.5)

        // Assert
        #expect(display == "1.5\u{00D7}")
    }

    @Test func nearlyWholeZoomRoundsToInteger() {
        // Act
        let display = ImageCanvasNSView.zoomDisplayString(2.98)

        // Assert
        #expect(display == "3\u{00D7}")
    }

    @Test func halfZoomShowsHalfFraction() {
        // Act
        let display = ImageCanvasNSView.zoomDisplayString(0.5)

        // Assert
        #expect(display == "\u{00BD}\u{00D7}")
    }

    @Test func thirdZoomShowsThirdFraction() {
        // Act
        let display = ImageCanvasNSView.zoomDisplayString(1.0 / 3.0)

        // Assert
        #expect(display == "\u{2153}\u{00D7}")
    }

    @Test func quarterZoomShowsQuarterFraction() {
        // Act
        let display = ImageCanvasNSView.zoomDisplayString(0.25)

        // Assert
        #expect(display == "\u{00BC}\u{00D7}")
    }
}
