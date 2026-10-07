---
title: Every Test Arranges, Acts and Asserts
impact: HIGH
impactDescription: A test with a step missing tests something other than it claims
tags: [testing, aaa, structure, swift-testing]
paths: ["ImageAlphaTests/**/*.swift"]
---

## Every Test Arranges, Acts and Asserts

**Impact: HIGH**

Every `@Test` has three steps, in this order, each present and identifiable,
and the suite marks them `// Arrange`, `// Act`, `// Assert`, with a short note
after the marker when the input needs one (`// Arrange: 3 pixels/row at 1-bit
depth exercises row bit padding`):

1. **Arrange** — build the input: an image from `makeTestCGImage`, a file from
   `writeTestPNG`, a model with an image loaded. When the input is a literal
   argument, the act carries it and the marker is left out, as in
   `ZoomDisplayTests`.
2. **Act** — the one call under test. One act per test where the design
   allows; a test that acts twice is two tests, or a test of the pair.
3. **Assert** — `#expect` against what the act produced; `try #require` for
   the thing the rest of the test can't run without.

**Incorrect (the act hidden inside the assert; no act at all):**

```swift
#expect(try await Quantizer().quantize(cgImage: image, options: QuantizationOptions()).pngData[25] == 3)

@Test func samplePaletteHasFourColors() { #expect(colors.count == 4) }
```

**Correct:**

```swift
// Arrange
let image = try makeImage(width: 32, height: 32, colors: [[255, 0, 0], [0, 255, 0], [0, 0, 255]])
let quantizer = Quantizer()

// Act
let result = try await quantizer.quantize(cgImage: image, options: QuantizationOptions())

// Assert: IHDR byte 25 is the color type; 3 means indexed
#expect(result.pngData[25] == 3)
```
