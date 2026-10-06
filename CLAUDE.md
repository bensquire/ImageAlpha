# ImageAlpha

ImageAlpha is a macOS document app that reduces a PNG to a palette with
libimagequant (pngquant's library) and saves it as an indexed PNG, alpha
included. It's AppKit with SwiftUI views, sandboxed, and targets macOS 15.

## Layout

| Path | What it is |
|---|---|
| `ImageAlphaApp.swift` | The `@main` app delegate and the hand-built main menu. |
| `ImageAlphaDocument.swift` | The `NSDocument`: reading, the overwrite confirmation on every save path, opening dropped files, Copy. |
| `DocumentModel.swift` | Per-document state (`@Observable`). Runs quantization 50 ms after a parameter stops changing, and the maximum-effort re-encode. |
| `Quantizer.swift` | An actor around libimagequant. It reads pixels as straight-alpha sRGB with vImage. |
| `IndexedPNGEncoder.swift` | Writes indexed PNGs (PLTE/tRNS) by hand: deflate from Compression for previews, libz level 9 for saves. |
| `BackgroundRenderer.swift` | Canvas backgrounds (checkerboard, colours, textures) and the cached texture images. |
| `Preferences.swift` | The `UserDefaults` keys. |
| `Views/` | The SwiftUI sidebar and status bar, plus `ImageCanvasNSView`, the layer-hosting canvas that handles zoom, pan, the cursor, and drag in and out. |
| `ImageAlphaTests/` | Swift Testing. Shared helpers (`makeTestCGImage`, `writeTestPNG`, …) are at the top of `IndexedPNGEncoderTests.swift`. |
| `pngquant/` | A submodule, built with cargo by `make pngquant`. |
| `samples/` | Test images. `dice.png` has plenty of partial alpha. |

## Commands

```
make test     # builds libimagequant, then runs the tests (ad-hoc signed)
make lint     # swiftlint --strict
make format   # swift-format in place, against .swift-format
```

## Where the rest lives

- **`.claude/skills/run-imagealpha/`** (`/run-imagealpha`): `driver.sh` builds
  the Debug app, launches it, clicks, drags and scrolls through it, and
  screenshots it. SKILL.md lists the traps.
- **`.claude/skills/apple-docs/`:** how to ask `scrapple`, the offline index of
  Apple's documentation, WWDC transcripts and sample code. It also covers where
  to look when a page is silent.
- **`.claude/rules/`:** one rule per file, indexed in `README.md`.
- **`.claude/hooks/`:** format with swift-format, then lint with SwiftLint,
  every Swift file as it's edited.
- **Preferences** persist in the sandbox container,
  `~/Library/Containers/net.pornel.ImageAlpha/Data/Library/Preferences/`.
  The Debug build shares them with any installed copy. The Tools → Dithering
  and Quality menus write them.
- **`CHANGELOG.md`** gains its entries when a version is released, not with
  each change.
