import AppKit
import QuartzCore

protocol ImageCanvasDelegate: AnyObject {
    func canvasDidReceiveDrop(urls: [URL])
    func canvasShowOriginalChanged(_ showOriginal: Bool)
}

class ImageCanvasNSView: NSView {

    weak var delegate: ImageCanvasDelegate?

    private var imageLayer: CALayer!
    private var backgroundLayer: CALayer!
    private var topShadow: CAGradientLayer!
    private var leftShadow: CAGradientLayer!

    private var mouseIsDown = false
    private var dragBackground = false
    private var dragStart: CGPoint = .zero

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

    var displayImage: NSImage? {
        didSet {
            if let alt = originalImage, let img = displayImage {
                let scale = getScale(of: alt)
                setScale(scale, of: img)
            }
            if zoomingToFill != 0 {
                zoomToFill(scale: zoomingToFill)
            }
            updateImageLayer()
        }
    }

    var originalImage: NSImage? {
        didSet {
            if let img = displayImage, let alt = originalImage {
                let scale = getScale(of: alt)
                setScale(scale, of: img)
            }
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

    var zoom: CGFloat = 2.0 {
        didSet {
            zoomingToFill = 0
            _setZoom(zoom)
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
        let b = hostLayer.bounds

        let stop0 = CGColor(gray: 0, alpha: 0)
        let stop1 = CGColor(gray: 0, alpha: 0.04)
        let stop2 = CGColor(gray: 0, alpha: 0.11)
        let stop3 = CGColor(gray: 0, alpha: 0.3)

        let top = CAGradientLayer()
        top.colors = [stop0, stop1, stop2, stop3]
        top.autoresizingMask = [.layerWidthSizable, .layerMinYMargin]
        top.frame = CGRect(x: 0, y: b.height - shadowHeight, width: b.width, height: shadowHeight)
        topShadow = top

        let left = CAGradientLayer()
        left.colors = [stop3, stop2, stop1, stop0]
        left.startPoint = CGPoint(x: 0, y: 0)
        left.endPoint = CGPoint(x: 1, y: 0)
        left.autoresizingMask = [.layerHeightSizable, .layerMaxXMargin]
        left.frame = CGRect(x: 0, y: 0, width: shadowWidth, height: b.height)
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
        _setZoom(z)
    }

    @objc func zoomIn(_ sender: Any?) {
        zoom = zoom * 2.0
    }

    @objc func zoomOut(_ sender: Any?) {
        zoom = zoom / 2.0
    }

    private func _setZoom(_ z: CGFloat) {
        let clamped = min(16.0, max(1.0 / 128.0, z))
        _zoom = clamped
        limitImageOffset()
        if clamped == 1.0 {
            imageLayer?.magnificationFilter = .nearest
        } else if smooth {
            imageLayer?.magnificationFilter = .linear
            imageLayer?.minificationFilter = .linear
        }
        repositionImageLayer()
    }

    private var _zoom: CGFloat = 2.0

    // MARK: - Image offset

    func limitImageOffset() {
        guard let img = originalImage ?? displayImage else { return }
        let size = frame.size
        let imgSize = img.size

        let w = (size.width + imgSize.width * _zoom) / 2
        let h = (size.height + imgSize.height * _zoom) / 2

        let x = max(-w + 15, min(w - 15, imageOffset.x))
        let y = max(-h + 15, min(h - 15, imageOffset.y))
        imageOffset = CGPoint(x: x, y: y)
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

    private func repositionImageLayer() {
        // Always use originalImage size for positioning so toggling showOriginal
        // doesn't change zoom/position. Fall back to displayImage if no original.
        guard let img = originalImage ?? displayImage else { return }
        let s = img.size
        let viewSize = bounds.size

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = CGRect(
            x: imageOffset.x + viewSize.width / 2 - s.width * _zoom / 2,
            y: imageOffset.y + viewSize.height / 2 - s.height * _zoom / 2,
            width: s.width * _zoom,
            height: s.height * _zoom
        )
        imageLayer.opacity = Float(imageFade)
        CATransaction.commit()
    }

    // MARK: - Image scale helpers

    private func getScale(of img: NSImage) -> NSSize {
        guard let rep = img.representations.first else { return .zero }
        let s = img.size
        guard s.width > 0, s.height > 0 else { return .zero }
        return NSSize(width: CGFloat(rep.pixelsWide) / s.width, height: CGFloat(rep.pixelsHigh) / s.height)
    }

    private func setScale(_ scale: NSSize, of img: NSImage) {
        guard let rep = img.representations.first, scale.width > 0, scale.height > 0 else { return }
        img.size = NSSize(width: CGFloat(rep.pixelsWide) / scale.width, height: CGFloat(rep.pixelsHigh) / scale.height)
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let bg = backgroundRenderer, bg.canMove {
            dragBackground = !pointIsInImage(point)
            if event.modifierFlags.contains([.shift]) || event.modifierFlags.contains([.option]) || event.modifierFlags.contains([.command]) {
                dragBackground = !dragBackground
            }
        } else {
            dragBackground = false
        }

        dragStart = CGPoint(x: point.x, y: point.y)

        if (event.clickCount & 3) == 2 {
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
        let point = convert(event.locationInWindow, from: nil)
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
        let oldZoom = _zoom
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
    override func touchesBegan(with event: NSEvent) {
        updateTouches(event)
    }

    override func touchesMoved(with event: NSEvent) {
        updateTouches(event)
    }

    override func touchesEnded(with event: NSEvent) {
        updateTouches(event)
    }

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

    // MARK: - Cursor

    override func resetCursorRects() {
        if displayImage != nil || originalImage != nil || backgroundRenderer != nil {
            let cursor: NSCursor = mouseIsDown ? .closedHand : .openHand
            addCursorRect(visibleRect, cursor: cursor)
            cursor.set()
        }
    }

    private func pointIsInImage(_ point: NSPoint) -> Bool {
        guard let img = displayImage ?? originalImage else { return false }
        let size = img.size
        let fsize = frame.size
        let w = max(50, size.width * _zoom + 15) / 2
        let h = max(50, size.height * _zoom + 15) / 2
        let offset = imageOffset
        return point.x >= offset.x + fsize.width / 2 - w &&
               point.y >= offset.y + fsize.height / 2 - h &&
               point.x <= offset.x + fsize.width / 2 + w &&
               point.y <= offset.y + fsize.height / 2 + h
    }

    // MARK: - Drag and Drop

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if hasFileURLs(sender.draggingPasteboard) {
            imageFade = 0.15
            return [.copy]
        }
        return []
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        imageFade = 1.0
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        imageFade = 1.0
        return hasFileURLs(sender.draggingPasteboard)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty else {
            return false
        }
        delegate?.canvasDidReceiveDrop(urls: urls)
        return true
    }

    private func hasFileURLs(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.availableType(from: [.fileURL]) != nil
    }
}
