---
title: Every Image Is as Small as It Can Be Without Showing It
impact: MEDIUM
impactDescription: An image that ships or sits in the README is downloaded by everyone; extra bytes there are paid for nothing
tags: [quality, images, assets, size, png]
paths: ["screenshot.png", "README.md", "textures/**", "ImageAlpha.icns", "samples/**"]
---

## Every Image Is as Small as It Can Be Without Showing It

**Impact: MEDIUM**

An image that is *presentation* — `screenshot.png` in the README, the
`textures/` the app ships as canvas backgrounds, the icon — is minified to the
highest degree that introduces no visible artefact. In order:

1. **The right container.** A photograph is WebP or JPEG; flat graphics,
   screenshots with text, icons and tiles are PNG.
2. **Lossless first.** `oxipng -o max --strip safe` for PNG; `jpegtran
   -optimize -progressive` for JPEG. Identical pixels, smaller file.
3. **Then lossy, to the edge.** For a PNG that is this app's job: quantize it
   in ImageAlpha (or with `pngquant`), lowering the colours until an artefact
   shows, then back up one step. `cwebp -q 90 -m 6` or JPEG quality 85–90
   for photographs.
4. **Look.** Side by side with the original at 1:1, on the busiest region; for
   a texture, tiled, since a seam only shows where tiles meet.

Report the before and after sizes in the commit.

This rule doesn't touch *test input*. `samples/dice.png` is the image the
driver's fixture copies and the hand-test for partial alpha; it stays exactly
as it is, because a smaller one would be a different test.

**Incorrect (stopping at lossless, or reporting no figures):**

```
screenshot.png   499 KB   oxipng -o max --strip safe (was 506 KB)
```

**Correct (both steps, the figures, and the look):**

```
screenshot.png   230 KB   256 colours, then oxipng -o max --strip safe (was 506 KB;
                          499 KB lossless alone); compared at 1:1 on the dice edges
```

The figures above are the current `screenshot.png`'s (6 October 2026). The
256-colour version was compared with the original at 1:1 on the window shadow
(over white and over GitHub's dark background), the text, the background
thumbnails and the dice; at 128 colours the water thumbnail lost its blue, so
256 is the step above that. `ImageAlpha.icns` is 75,636 bytes (was 111,804):
`oxipng` on its 512-pixel PNG, the other entries and the table of contents
rebuilt around it, every size decoding to the same pixels.
