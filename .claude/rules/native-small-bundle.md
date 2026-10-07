---
title: Small, Because the System Does the Rest
impact: MEDIUM
impactDescription: The app is 1.3 MB with libimagequant linked in; growth is a signal the wrong path was taken
tags: [native, macos, bundle, dependencies, size]
paths: ["ImageAlpha.xcodeproj/**", "*.xcconfig", "Makefile", "textures/**", "pngquant"]
---

## Small, Because the System Does the Rest

**Impact: MEDIUM**

The Release `ImageAlpha.app` is about 1.3 MB (6 October 2026, `make
release`): a 932 KB arm64 executable with libimagequant linked in statically,
276 KB of textures, a 76 KB icon, and no `Frameworks` folder. There are no
Swift package dependencies; zlib, vImage, Compression and ImageIO are the
system's. `release.xcconfig` builds for size (`-Osize`, dead-code stripping,
stripped symbols), and `make pngquant` builds libimagequant with thin LTO and
one codegen unit.

That size is a consequence of using the system's features and a check on
them. A feature that arrives with a package, a bundled image library, or a
second copy of something macOS provides is a sign the wrong path was taken.
Check after a change that could grow it:

```sh
make release
du -sh ~/Library/Developer/Xcode/DerivedData/ImageAlpha-*/Build/Products/Release/ImageAlpha.app
```

Growth needs a reason, stated in the commit with the before and after.

**Incorrect:**

```
Add the libpng package to write indexed PNGs   # IndexedPNGEncoder does it in about 220 lines on system zlib
```

**Correct:**

```swift
import Compression   // already on every Mac
```
