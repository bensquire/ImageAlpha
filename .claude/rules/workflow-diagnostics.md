---
title: Diagnostics Go Through the Logger to Keep, a Separate File to Throw Away
impact: MEDIUM
impactDescription: A debug block woven into the quantizer has to be edited out of the quantizer
tags: [workflow, diagnostics, logging, os-log]
paths: ["*.swift", "Views/**/*.swift"]
---

## Diagnostics Go Through the Logger to Keep, a Separate File to Throw Away

**Impact: MEDIUM**

The app is launched by Launch Services and sandboxed, so `print` goes nowhere
anyone reads. Diagnostics worth keeping go through `os.Logger` with the app's
subsystem, `net.pornel.ImageAlpha`, and a category per type, as
`DocumentModel.logger` does. Use `.debug` for detail: debug-level messages are
only captured when debug logging is enabled
(/documentation/os/os_log_type_t/os_log_type_debug), so they cost nothing in
normal use. Read them with
`log stream --level debug --predicate 'subsystem == "net.pornel.ImageAlpha"'`.

Diagnostics for one investigation go in a separate file, marked temporary, and
are deleted before handover. Weaving them into `Quantizer` or
`IndexedPNGEncoder` means editing the hot path again to take them out.

**Incorrect (a dump inline in the quantizer):**

```swift
let quantErr = liq_image_quantize(liqImage, attr, &resultPtr)
print("quantize", width, height, options, quantErr)   // nobody sees stdout
```

**Correct (kept, at debug level, through the logger; or a temporary file of its own):**

```swift
Self.logger.debug("quantized \(width)×\(height) to \(colorCount) colors")

// DebugDump.swift — TEMPORARY, not for commit
func dumpPalette(_ palette: [IndexedPNGEncoder.PaletteEntry]) { … }
```
