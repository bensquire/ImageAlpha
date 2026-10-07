---
title: Fast Where It Counts, and Measured
impact: HIGH
impactDescription: Scrubbing a slider asks for a new quantization on every change; on a 12 MP image libimagequant alone takes about half a second
tags: [quality, performance, concurrency, encoding, allocation]
paths: ["*.swift", "Views/**/*.swift"]
---

## Fast Where It Counts, and Measured

**Impact: HIGH**

The cost is in a few places, and they are written for the machine:

- **Quantization.** libimagequant took about 450 ms on a 12 MP image. A
  parameter change waits 50 ms for the slider to settle, `Quantizer` checks
  `Task.checkCancellation()` before and during the work so a superseded request
  stops, identical options are skipped, and the last two results are kept so
  switching modes restores one without quantizing again.
- **Encoding.** On the same image the encoder was the slowest phase, 990 ms,
  until `packScanlines` stopped appending byte by byte (410 ms to 2 ms). It is
  now bound by deflate. Previews use Compression's fast zlib; the level-9 libz
  encode (2–7 % smaller on large images) runs off the main actor, 400 ms after
  the result settles, and a save asks for it directly through `finalPNGData()`.
- **The canvas.** Layer-hosting, with the background as a layer, so panning
  moves layers rather than redrawing.

Everything else is written for the reader. Which is which is decided by
measuring — on a large image, before and after, with the figures in the commit
and in the comment on the fast path.

**Incorrect (the work on every slider tick, and nothing can stop it):**

```swift
var numberOfColors = 256 { didSet { Task { await quantizer.quantize(cgImage: image, options: options) } } }
```

**Correct (debounced, cancellable, skipped when nothing changed):**

```swift
parameterTask?.cancel()
parameterTask = Task { [weak self] in
    try? await Task.sleep(for: .milliseconds(50))
    guard let self, !Task.isCancelled else { return }
    self.requestQuantization()   // returns at once if the options produced the current result
}
```
