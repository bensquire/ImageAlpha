import AppKit
import QuartzCore
import UniformTypeIdentifiers

protocol ImageCanvasDelegate: AnyObject {
    func canvasDidReceiveDrop(urls: [URL])
    func canvasShowOriginalChanged(_ showOriginal: Bool)
}

class ImageCanvasNSView: NSView, NSDraggingSource, NSFilePromiseProviderDelegate {

    weak var delegate: ImageCanvasDelegate?
    var pngDataProvider: (() -> Data?)?

    var imageLayer: CALayer!
    private var backgroundLayer: CALayer!
    private var topShadow: CAGradientLayer!
    private var leftShadow: CAGradientLayer!

    var mouseIsDown = false
    private var dragBackground = false
    private var dragStart: CGPoint = .zero
    private var potentialDragStart: CGPoint?
    var isDraggingOut = false

    var checkerboardStyle: ImageAlpha.BackgroundStyle? {
        didSet {
            applyBackground()
        }
    }

    var backgroundRenderer: BackgroundRendering? {
        didSet {
            guard let renderer = backgroundRenderer else { return }
            let newLayer = renderer.makeLayer()
            newLayer.frame = bounds
            newLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer?.replaceSublayer(backgroundLayer, with: newLayer)
            backgroundLayer = newLayer
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyBackground()
    }

    private func applyBackground() {
        guard let style = checkerboardStyle else { return }
        backgroundRenderer = makeBackgroundRenderer(for: style)
    }

    var displayImage: NSImage? {
        didSet {
            syncImageScale()
            if zoomingToFill != 0 {
                zoomToFill(scale: zoomingToFill)
            }
            updateImageLayer()
        }
    }

    var originalImage: NSImage? {
        didSet {
            syncImageScale()
            imageOffset = .zero
            zoomToFill()
            updateImageLayer()
        }
    }

    var showOriginal: Bool = false {
        didSet {
            updateImageLayer()
        }
    }

    var splitPosition: CGFloat? {
        didSet {
            updateSplitLayers()
            window?.invalidateCursorRects(for: self)
        }
    }

    private var originalLayer: CALayer?
    private var splitDividerLayer: CALayer?
    private var isDraggingSplit = false

    var zoom: CGFloat = 2.0 {
        didSet {
            zoomingToFill = 0
            applyZoom(zoom)
        }
    }

    private(set) var zoomingToFill: CGFloat = 0
    var imageOffset: CGPoint = .zero

    var smooth: Bool = true {
        didSet {
            imageLayer?.magnificationFilter = smooth ? .linear : .nearest
            imageLayer?.minificationFilter = smooth ? .linear : .nearest
        }
    }

    var imageFade: CGFloat = 1.0 {
        didSet {
            imageLayer?.opacity = Float(imageFade)
        }
    }

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        let hostLayer = CALayer()
        self.layer = hostLayer
        self.wantsLayer = true

        backgroundLayer = CALayer()
        backgroundLayer.frame = bounds
        backgroundLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        backgroundLayer.backgroundColor = CGColor(gray: 0.5, alpha: 1)

        imageLayer = CALayer()
        imageLayer.magnificationFilter = .linear
        imageLayer.minificationFilter = .linear
        imageLayer.contentsGravity = .resize

        hostLayer.addSublayer(backgroundLayer)
        hostLayer.addSublayer(imageLayer)

        addShadows()
        registerForDraggedTypes([.fileURL])
        setUpTrackingArea()
    }

    private func setUpTrackingArea() {
        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    private func addShadows() {
        guard let hostLayer = layer else { return }
        let shadowHeight: CGFloat = 10
        let shadowWidth: CGFloat = 12
        let hostBounds = hostLayer.bounds

        let stop0 = CGColor(gray: 0, alpha: 0)
        let stop1 = CGColor(gray: 0, alpha: 0.04)
        let stop2 = CGColor(gray: 0, alpha: 0.11)
        let stop3 = CGColor(gray: 0, alpha: 0.3)

        let top = CAGradientLayer()
        top.colors = [stop0, stop1, stop2, stop3]
        top.autoresizingMask = [.layerWidthSizable, .layerMinYMargin]
        top.frame = CGRect(x: 0, y: hostBounds.height - shadowHeight, width: hostBounds.width, height: shadowHeight)
        topShadow = top

        let left = CAGradientLayer()
        left.colors = [stop3, stop2, stop1, stop0]
        left.startPoint = CGPoint(x: 0, y: 0)
        left.endPoint = CGPoint(x: 1, y: 0)
        left.autoresizingMask = [.layerHeightSizable, .layerMaxXMargin]
        left.frame = CGRect(x: 0, y: 0, width: shadowWidth, height: hostBounds.height)
        leftShadow = left

        hostLayer.addSublayer(left)
        hostLayer.addSublayer(top)
    }

    // MARK: - Frame

    override var frame: NSRect {
        didSet {
            if zoomingToFill != 0 {
                zoomToFill(scale: zoomingToFill)
            } else {
                repositionImageLayer()
            }
        }
    }

    override var isOpaque: Bool { backgroundRenderer != nil }

    // MARK: - Zoom

    func zoomToFill(scale: CGFloat = 1.0) {
        zoomingToFill = scale
        // Always use originalImage size for consistency (same as repositionImageLayer)
        guard let img = originalImage ?? displayImage else { return }
        let size = img.size
        let frameSize = frame.size
        guard frameSize.width > 0, frameSize.height > 0 else { return }
        var z = min(frameSize.width / size.width, frameSize.height / size.height) * scale
        if z > 1.0 {
            z = min(4.0, floor(z))
        }
        applyZoom(z)
    }

    @objc func zoomIn(_ sender: Any?) {
        zoom *= 2.0
    }

    @objc func zoomOut(_ sender: Any?) {
        zoom /= 2.0
    }

    private func applyZoom(_ z: CGFloat) {
        let clamped = min(16.0, max(1.0 / 128.0, z))
        currentZoom = clamped
        limitImageOffset()
        if clamped == 1.0 {
            imageLayer?.magnificationFilter = .nearest
        } else if smooth {
            imageLayer?.magnificationFilter = .linear
            imageLayer?.minificationFilter = .linear
        }
        repositionImageLayer()
    }

    var currentZoom: CGFloat = 2.0

    // MARK: - Image offset

    func limitImageOffset() {
        guard let img = originalImage ?? displayImage else { return }
        let size = frame.size
        let imgSize = img.size

        let halfWidth = (size.width + imgSize.width * currentZoom) / 2
        let halfHeight = (size.height + imgSize.height * currentZoom) / 2

        let clampedX = max(-halfWidth + 15, min(halfWidth - 15, imageOffset.x))
        let clampedY = max(-halfHeight + 15, min(halfHeight - 15, imageOffset.y))
        imageOffset = CGPoint(x: clampedX, y: clampedY)
    }

    // MARK: - Zoom value accessors (non-linear slider mapping)

    static func sliderToZoom(_ sliderValue: CGFloat) -> CGFloat {
        sliderValue < 3.0 ? 1.0 / (4.0 - sliderValue) : sliderValue - 2.0
    }

    static func zoomToSlider(_ z: CGFloat) -> CGFloat {
        z < 1.0 ? max(0, 4.0 - 1.0 / z) : z + 2.0
    }

    static func zoomDisplayString(_ z: CGFloat) -> String {
        if z >= 1.0 {
            return "\(Int(z))\u{00D7}"
        }
        let fractions = ["\u{00BD}\u{00D7}", "\u{2153}\u{00D7}", "\u{00BC}\u{00D7}"]
        let idx = min(2, max(0, Int(round(1.0 / z)) - 2))
        return fractions[idx]
    }

    // MARK: - Layer updates

    private func updateImageLayer() {
        let img = showOriginal ? originalImage : displayImage
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let img = img {
            var rect = NSRect(origin: .zero, size: img.size)
            imageLayer.contents = img.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        } else {
            imageLayer.contents = nil
        }
        repositionImageLayer()
        CATransaction.commit()
    }

    private func updateSplitLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let pos = splitPosition {
            // Create original layer if needed
            if originalLayer == nil {
                let oLayer = CALayer()
                oLayer.magnificationFilter = .linear
                oLayer.minificationFilter = .linear
                oLayer.contentsGravity = .resize
                layer?.insertSublayer(oLayer, above: imageLayer)
                originalLayer = oLayer

                let divider = CALayer()
                divider.backgroundColor = CGColor(gray: 1, alpha: 0.8)
                layer?.insertSublayer(divider, above: oLayer)
                splitDividerLayer = divider
            }

            // Set original image contents on the original layer
            if let img = originalImage {
                var rect = NSRect(origin: .zero, size: img.size)
                originalLayer?.contents = img.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            }
            originalLayer?.isHidden = false
            splitDividerLayer?.isHidden = false

            // Clip: original layer shows left half, imageLayer clipped to right half
            let viewWidth = bounds.width
            let dividerX = viewWidth * pos
            originalLayer?.frame = imageLayer.frame
            applySplitMasks(dividerX: dividerX, imageFrame: imageLayer.frame)

            // Divider line
            splitDividerLayer?.frame = CGRect(x: dividerX - 2, y: 0, width: 4, height: bounds.height)
        } else {
            originalLayer?.isHidden = true
            splitDividerLayer?.isHidden = true
            originalLayer?.mask = nil
            imageLayer.mask = nil
        }
        CATransaction.commit()
    }

    private func applySplitMasks(dividerX: CGFloat, imageFrame: CGRect) {
        let leftClip = dividerX - imageFrame.origin.x

        let origMask = CALayer()
        origMask.backgroundColor = CGColor.black
        origMask.frame = CGRect(x: 0, y: 0, width: leftClip, height: imageFrame.height)
        originalLayer?.mask = origMask

        let imgMask = CALayer()
        imgMask.backgroundColor = CGColor.black
        imgMask.frame = CGRect(x: leftClip, y: 0, width: imageFrame.width - leftClip, height: imageFrame.height)
        imageLayer.mask = imgMask
    }

    private func repositionImageLayer() {
        // Always use originalImage size for positioning so toggling showOriginal
        // doesn't change zoom/position. Fall back to displayImage if no original.
        guard let image = originalImage ?? displayImage else { return }
        let imageSize = image.size
        let viewSize = bounds.size

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let imageFrame = CGRect(
            x: imageOffset.x + viewSize.width / 2 - imageSize.width * currentZoom / 2,
            y: imageOffset.y + viewSize.height / 2 - imageSize.height * currentZoom / 2,
            width: imageSize.width * currentZoom,
            height: imageSize.height * currentZoom
        )
        imageLayer.frame = imageFrame
        imageLayer.opacity = Float(imageFade)
        // Update split layers if active
        if let pos = splitPosition {
            originalLayer?.frame = imageFrame
            let viewWidth = bounds.width
            let dividerX = viewWidth * pos
            applySplitMasks(dividerX: dividerX, imageFrame: imageFrame)
            splitDividerLayer?.frame = CGRect(x: dividerX - 2, y: 0, width: 4, height: bounds.height)
        }
        CATransaction.commit()
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

    private func syncImageScale() {
        guard let original = originalImage, let display = displayImage else { return }
        let scale = getScale(of: original)
        setScale(scale, of: display)
    }

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    // MARK: - NSFilePromiseProviderDelegate

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        fileNameForType fileType: String
    ) -> String {
        "ImageAlpha.png"
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        do {
            if let data = pngDataProvider?() {
                try data.write(to: url)
            }
            handler(nil)
        } catch {
            handler(error)
        }
    }

    func beginImageDrag(from event: NSEvent) {
        guard let data = pngDataProvider?() else { return }
        isDraggingOut = true

        let provider = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: self)
        provider.userInfo = data

        let draggingItem = NSDraggingItem(pasteboardWriter: provider)
        draggingItem.setDraggingFrame(imageLayer.frame, contents: displayImage ?? originalImage)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func pointIsInImage(_ point: NSPoint) -> Bool {
        guard let image = displayImage ?? originalImage else { return false }
        let imageSize = image.size
        let frameSize = frame.size
        let halfWidth = max(50, imageSize.width * currentZoom + 15) / 2
        let halfHeight = max(50, imageSize.height * currentZoom + 15) / 2
        let offset = imageOffset
        return point.x >= offset.x + frameSize.width / 2 - halfWidth &&
               point.y >= offset.y + frameSize.height / 2 - halfHeight &&
               point.x <= offset.x + frameSize.width / 2 + halfWidth &&
               point.y <= offset.y + frameSize.height / 2 + halfHeight
    }
}

// MARK: - Mouse & Gesture Events

extension ImageCanvasNSView {

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        isDraggingOut = false

        if let bg = backgroundRenderer, bg.canMove {
            dragBackground = !pointIsInImage(point)
            if event.modifierFlags.contains([.shift])
                || event.modifierFlags.contains([.option])
                || event.modifierFlags.contains([.command]) {
                dragBackground = !dragBackground
            }
        } else {
            dragBackground = false
        }

        dragStart = CGPoint(x: point.x, y: point.y)

        // Check if clicking near the split divider
        if let pos = splitPosition {
            let dividerX = bounds.width * pos
            if abs(point.x - dividerX) < 8 {
                isDraggingSplit = true
                return
            }
        }

        // Track potential drag-out if clicking on the image with quantized data available
        if !dragBackground && pointIsInImage(point) && pngDataProvider?() != nil {
            potentialDragStart = point
        } else {
            potentialDragStart = nil
        }

        if (event.clickCount & 3) == 2 {
            potentialDragStart = nil
            imageOffset = .zero
            if zoomingToFill != 0 {
                zoom = 1.0
            } else {
                zoomToFill()
            }
        } else {
            mouseIsDown = true
            window?.invalidateCursorRects(for: self)
            mouseDragged(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDraggingOut else { return }

        let point = convert(event.locationInWindow, from: nil)

        // Handle split divider dragging
        if isDraggingSplit {
            let newPos = max(0.05, min(0.95, point.x / bounds.width))
            splitPosition = newPos
            return
        }

        // Check if we should start a drag-out session
        if let start = potentialDragStart {
            let dx = point.x - start.x
            let dy = point.y - start.y
            if dx * dx + dy * dy > 16 { // 4px threshold
                potentialDragStart = nil
                beginImageDrag(from: event)
                return
            }
        }

        let dx = point.x - dragStart.x
        let dy = point.y - dragStart.y
        dragStart = CGPoint(x: point.x, y: point.y)

        if let bg = backgroundRenderer, dragBackground {
            bg.moveBy(NSSize(width: dx, height: dy))
        } else if displayImage != nil || originalImage != nil {
            imageOffset = CGPoint(x: imageOffset.x + dx, y: imageOffset.y + dy)
            limitImageOffset()
        }
        repositionImageLayer()
    }

    override func mouseUp(with event: NSEvent) {
        mouseIsDown = false
        potentialDragStart = nil
        isDraggingOut = false
        isDraggingSplit = false
        window?.invalidateCursorRects(for: self)
    }

    override func scrollWheel(with event: NSEvent) {
        if event.deltaY > 0 {
            zoomIn(nil)
        } else if event.deltaY < 0 {
            zoomOut(nil)
        }
    }

    override func magnify(with event: NSEvent) {
        let oldZoom = currentZoom
        var z: CGFloat
        if oldZoom + event.magnification > 1 {
            z = ((oldZoom / 20) + event.magnification / 4) * 20
        } else {
            z = 1 / (1 / oldZoom - event.magnification)
        }
        if (z > 1.0 && oldZoom < 1.0) || (z < 1.0 && oldZoom > 1.0) {
            z = 1.0
        }
        zoom = max(0.25, z)
    }

    // 3-finger touch to show original
    override func touchesBegan(with event: NSEvent) { updateTouches(event) }
    override func touchesMoved(with event: NSEvent) { updateTouches(event) }
    override func touchesEnded(with event: NSEvent) { updateTouches(event) }

    private func updateTouches(_ event: NSEvent) {
        let touches = event.touches(matching: .stationary, in: self)
        let show = touches.count >= 3
        if showOriginal != show {
            showOriginal = show
            delegate?.canvasShowOriginalChanged(show)
        }
    }

    override func otherMouseDown(with event: NSEvent) {
        showOriginal = true
        delegate?.canvasShowOriginalChanged(true)
    }

    override func otherMouseUp(with event: NSEvent) {
        showOriginal = false
        delegate?.canvasShowOriginalChanged(false)
    }

}
