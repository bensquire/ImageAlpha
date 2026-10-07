---
title: Every Run Gives the Same Answer
impact: HIGH
impactDescription: A flaky test is a test nobody trusts
tags: [testing, determinism, fixtures, preferences]
paths: ["ImageAlphaTests/**/*.swift"]
---

## Every Run Gives the Same Answer

**Impact: HIGH**

- **Fixtures are generated.** Images come from `makeTestCGImage` and the
  builders in each suite; pseudo-random pixels come from a seeded generator
  written in the test (the LCG in
  `indexedOutputIsSmallerThanImageIORGBAEncoding`), not `Int.random`.
- **Files go in their own temporary directory** (`makeTemporaryDirectory`,
  `writeTemporaryFile`, `writeTestPNG`), so no test sees another's files or
  depends on the order tests run in.
- **Preferences are isolated.** `PreferencesTests` is `.serialized` and swaps
  `Preferences.defaults` for one fixed suite, emptied before and after. The
  test host is the app itself, so `DocumentModel` reads the real dithering and
  speed preferences when it is made: a test whose outcome depends on them sets
  them on the model.
- **No network.** Nothing in the app uses one, and no test should.
- **Waiting is for something.** An async result is awaited
  (`try await quantizer.quantize(…)`), not slept for. The one deliberate wait
  is for `DocumentModel`'s 50 ms debounce: those tests sleep 200 ms, four times
  it, and assert what happened (`edits == 1`), not when.

**Incorrect:**

```swift
let pixels = (0..<(64 * 64)).map { _ in UInt8.random(in: 0..<16) }
let url = FileManager.default.temporaryDirectory.appendingPathComponent("image.png")   // shared by every run
```

**Correct:**

```swift
var seed: UInt64 = 0x2545_F491_4F6C_DD1D
let pixels: [UInt8] = (0..<(width * height)).map { _ in
    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return UInt8((seed >> 33) % 16)
}
let url = try writeTestPNG(named: "image.png")   // its own directory
```
