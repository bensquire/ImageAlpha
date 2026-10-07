---
title: Each Part Does One Job, and Knows Only Its Neighbours
impact: HIGH
impactDescription: The encoder and the quantizer are tested headlessly because neither knows about a window or a document
tags: [quality, architecture, separation-of-concerns, layers]
paths: ["*.swift", "Views/**/*.swift"]
---

## Each Part Does One Job, and Knows Only Its Neighbours

**Impact: HIGH**

The app is one target, so the layers are kept by the types, and the
dependencies run one way:

- **`IndexedPNGEncoder`** turns an `IndexedBitmap` (palette and indices) into
  PNG bytes. It imports Foundation and Compression only, and knows nothing of
  how the palette was made.
- **`Quantizer`** is an actor around libimagequant: pixels and
  `QuantizationOptions` in, a `QuantizationResult` out. It knows nothing of
  documents, preferences or the UI.
- **`DocumentModel`** owns one document's state and decides what to ask for:
  `effectiveOptions` is the one place the sidebar's mode, colour count and
  quality target become options, or 24-bit passthrough.
- **`ImageAlphaDocument`** is the file: reading, saving, the overwrite
  confirmation, opening dropped files, Copy.
- **`Views/`** shows the model and sends the user's changes to it.
  `ImageCanvasNSView` draws, zooms and drags; it asks for the PNG to drag out
  rather than knowing where it came from.
- **`Preferences`** holds every `UserDefaults` key and its validation.

A change that needs the encoder to know about libimagequant, a view to decide
quantization options, or the quantizer to read a preference, is at the wrong
layer.

**Incorrect (a view deciding something the model owns):**

```swift
// ImageCanvasView.updateNSView
nsView.displayImage = model.numberOfColors > 256 ? model.sourceImage : model.quantizedImage
```

**Correct (the model states the rule; the view shows the result):**

```swift
// DocumentModel
var effectiveOptions: QuantizationOptions? {
    if quantizationMode == .colors && numberOfColors > 256 { return nil }
    …
}
// ImageCanvasView.updateNSView
nsView.displayImage = model.quantizedImage   // the source itself, in passthrough
```
