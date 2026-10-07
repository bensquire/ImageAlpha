---
title: Sandboxed, Offline, and Nothing Overwritten Without Asking
impact: HIGH
impactDescription: An image tool that reaches past the files it was given, or replaces one the user didn't agree to, has broken trust
tags: [quality, security, privacy, sandbox, files, unsafe]
paths: ["*.swift", "Views/**/*.swift", "ImageAlpha.entitlements", "Makefile", ".github/workflows/**"]
---

## Sandboxed, Offline, and Nothing Overwritten Without Asking

**Impact: HIGH**

- **Sandboxed, with two entitlements.** App Sandbox and user-selected
  read-write (`ImageAlpha.entitlements`). An entitlement is added only with the
  feature that needs it.
- **No network, no child processes.** The app has no network entitlement and
  spawns nothing. Help hands the project's URL to the browser, and the
  "Optimize with ImageOptim" option hands the saved file to ImageOptim, both
  through `NSWorkspace`. Nothing is sent anywhere, and there is no telemetry.
- **Input is untrusted.** A PNG can come from anywhere. Drops accept only the
  types in `Info.plist`; `read(from:ofType:)` decodes and throws, so a file
  that isn't an image fails the open; `IndexedPNGEncoder.encode` validates its
  sizes and indices before it writes a byte.
- **Unsafe memory is owned and bounded.** libimagequant is C. The buffers it
  reads and writes are allocated with their size computed from the image and
  freed with `defer` in the same scope, and they outlive the calls that point
  into them.
- **Nothing is overwritten without asking.** Every save to the open file goes
  through `save(withDelegate:didSave:contextInfo:)` and its "Overwrite original
  file?" alert, then NSDocument's own save, which also notices if another app
  changed the file. A drag out writes with `.withoutOverwriting`.
- **Signed, hardened and notarised.** `make sign` signs with Developer ID, the
  hardened runtime and the entitlements; `release.yml` notarises and staples
  the DMG.

**Incorrect:**

```swift
fileURL = droppedURL                                      // Save would write PNG bytes over a dropped JPEG
try promised.data.write(to: url)                          // replaces whatever is there
```

**Correct:**

```swift
NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in opened(error) }
try promised.data.write(to: url, options: .withoutOverwriting)
```
