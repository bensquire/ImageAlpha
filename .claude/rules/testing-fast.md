---
title: Fast, but Not Over Accuracy
impact: MEDIUM
impactDescription: A test that is quick because it cannot see the defect is not a test; a slow suite is one nobody runs
tags: [testing, performance, accuracy, fixtures]
paths: ["ImageAlphaTests/**/*.swift"]
---

## Fast, but Not Over Accuracy

**Impact: MEDIUM**

A test is first for what it proves, then as cheap as that allows — never the
other way round. The 100 tests (a parameterised test counts once) take 0.3 s; `make test` takes 6–10 s warm,
nearly all of it the build. Speed is bought by not paying for what the test
doesn't need: images are built in memory, most of them 64×64 or smaller; a rule about one
unit is pinned on that unit (`packScanlines` on an index array,
`bitDepth(forPaletteCount:)` on a count) rather than on a whole quantization.

Speed is never bought by making the test see less. The colour-reduction test
uses a 64×64 gradient because it must start with far more colours than the
16 it asks for; the size test uses 64×64 varied indices so deflate has
something to do. A fixture shrunk until the defect wouldn't show, or a bound
loosened so a small fixture clears it, is a faster test that no longer tests.
Timing a 12 MP image is a benchmark, run by hand with its figures in the
commit, not a unit test.

**Incorrect (fast because it cannot see):**

```swift
let image = try makeImage(width: 4, height: 4, colors: [[255, 0, 0]])   // one colour: passes if nothing was reduced
#expect(uniqueColors(in: decoded.rgba).count <= 16)
```

**Correct (small where it costs nothing to be; big enough where it counts):**

```swift
// Arrange: 64x64 gradient with far more than 16 unique colors
let image = try makeGradientImage(width: 64, height: 64)
let options = QuantizationOptions(numberOfColors: 16)
```
