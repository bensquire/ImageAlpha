---
title: Use the System's Feature, Not a Copy of It
impact: HIGH
impactDescription: The OS version already handles accessibility, Dark Mode, file coordination and next year's macOS
tags: [native, macos, appkit, swiftui, nsdocument, drag-and-drop]
paths: ["*.swift", "Views/**/*.swift"]
---

## Use the System's Feature, Not a Copy of It

**Impact: HIGH**

ImageAlpha should feel like a Mac app Apple could have shipped: it behaves the
way the user's other apps behave, by using what macOS provides rather than
building a version of its own. Before writing a panel, a sheet, a drop handler
or a file format, ask whether the OS has one. It usually does.

- **Files** are `NSDocument`: opening, Save, Save As, Revert, the close and
  quit sheets, and noticing when another app changed the file. A dropped file
  opens as a document of its own through `NSDocumentController`.
- **Asking** is an `NSAlert` run as a sheet on the document's window; the Save
  panel's extra option is an accessory view on `NSSavePanel`.
- **Copy and drag** are `NSPasteboardItem` (PNG and TIFF on one item),
  `NSFilePromiseProvider` for dragging out, and `NSFilePromiseReceiver` for
  images dragged in from Photos, Mail or a browser.
- **Pixels and compression** are vImage for reading straight-alpha sRGB, and
  Compression and libz for deflate.
- **Controls** are SwiftUI's, labelled for VoiceOver even when the label is
  hidden; cursors are `NSCursor`'s; colours follow the view's appearance.
- **Opening another app or a page** is `NSWorkspace`.

When the system can't do the job, say so in a comment with the page that shows
it, as `IndexedPNGEncoder` does: ImageIO documents no way to write a palette,
so the indexed PNG is written by hand.

Native is not generic: the canvas, the compare split and the status line are
the app's own work, built from the system's parts.

**Incorrect (a document by hand — Save then writes PNG bytes over a dropped JPEG):**

```swift
fileURL = url
try model.loadImage(from: url)
```

**Correct (the system's):**

```swift
NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in opened(error) }
```
