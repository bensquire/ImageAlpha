---
title: Ground Truth Is the Decoded PNG, and the Bar Has Teeth
impact: HIGH
impactDescription: A file can be a valid PNG of the right size and still hold the wrong pixels
tags: [testing, ground-truth, png, decoding, fixtures]
paths: ["ImageAlphaTests/**/*.swift"]
---

## Ground Truth Is the Decoded PNG, and the Bar Has Teeth

**Impact: HIGH**

Build the input so its answer is known — a few exact colours, a gradient with
far more colours than any palette, a half-transparent half-opaque image — then
judge the output by decoding it with ImageIO (`DecodedImage`) and comparing
pixels: the colours that came back, the alpha row by row, the unique-colour
count. Header bytes (colour type, bit depth) and chunk presence are checked
too, but they are not the proof.

When a test says a result is good, it also says, where it can, what the
alternative would have measured, so the bar can't be cleared by accident:
`indexedOutputIsSmallerThanImageIORGBAEncoding` beats ImageIO's truecolor
encode of the same pixels, and
`maximumEffortDecodesIdenticallyAndIsNoLarger` decodes both efforts and
compares them. A tolerance carries the reason for its size — `DecodedImage`
premultiplies, so a semi-transparent pixel can only be checked approximately.
When a bug is fixed, a test pins it, with the measurement that showed it.

**Incorrect (a bar with no teeth — passes on output that did nothing):**

```swift
#expect(!result.pngData.isEmpty)
#expect(result.paletteCount <= 16)
```

**Correct (the decoded pixels, and the alternative measured too):**

```swift
let decoded = try decodeRGBA(result.pngData)
#expect(uniqueColors(in: decoded.rgba).count <= 16)   // from a 64×64 gradient with far more

let indexed = try #require(IndexedPNGEncoder.encode(width: width, height: height, palette: palette, pixels: pixels))
#expect(indexed.count < imageIOData.count)            // ImageIO's truecolor file of the same pixels
```
