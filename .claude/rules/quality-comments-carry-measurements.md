---
title: A Comment Is Short, and Says Why
impact: HIGH
impactDescription: A comment costs every reader time and every token money; it earns that or it goes
tags: [quality, comments, documentation, measurements, brevity]
paths: ["*.swift", "Views/**/*.swift"]
---

## A Comment Is Short, and Says Why

**Impact: HIGH**

A comment adds what the code cannot say — why this, what was measured, what was
rejected — in as few plain words as will still read. It doesn't restate a
method or property name. A claim carries its measurement: the image, before,
after. A constant carries the reason for its value. A decision that rests on
Apple's documentation carries the page's path, as
`native-check-apples-documentation` asks. A comment about code that has gone
goes with it.

**Incorrect (restates the name; no reason; no source):**

```swift
/// Reads the pixels.
private static func readStraightRGBA(_ cgImage: CGImage, into destination: UnsafeMutableRawPointer) -> Bool
```

**Correct (the why, the source, then stop):**

```swift
/// Writes the image into `destination` as straight-alpha sRGB RGBA, rows
/// packed at width × 4 bytes, the layout libimagequant reads. vImage
/// converts directly; a CGBitmapContext premultiplies, and undoing that
/// loses the colour of nearly transparent pixels.
/// /documentation/accelerate/vimagebuffer_initwithcgimage(_:_:_:_:_:)
```
