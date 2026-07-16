# Changelog

## Unreleased

- Quantized PNGs are now written as true 8-bit indexed PNGs (PLTE/tRNS, with
  1/2/4-bit packing for small palettes) instead of 32-bit RGBA — dramatically
  smaller files, which is the point of the app
- Removed the "IE6-friendly alpha" option: it has been a silent no-op since
  the Rust libimagequant port (`liq_set_min_opacity` is a deprecated stub)
- Semi-transparent pixels no longer lose precision before quantization
  (vImage unpremultiply with correct rounding replaces integer math)
- Fixed a race where loading a second image while the first was still being
  analyzed could show the wrong "Original: N colors" count
- Copy (Cmd+C) now puts a single pasteboard item with PNG and TIFF
  representations on the clipboard, so paste targets get the quantized image
- Scroll-wheel zoom now accumulates trackpad deltas instead of doubling the
  zoom on every event
- Documents now track unsaved changes (edited dot, save prompt on close), and
  the status bar refreshes after overwriting the original file
- Drag-and-drop only accepts image files, and dropping multiple images opens
  each in its own window
- Fractional zoom levels display with one decimal (e.g. "1.5×") instead of
  truncating
- Centralized preferences handling; removed debug logging; spelling
  consistency ("colors")

## v0.0.9

- Fixed drag-and-drop onto the canvas being broken in v0.0.8: a duplicate object ID
  in the Xcode project caused `ImageCanvasNSView+DragDrop.swift` to be silently
  excluded from the build, so the app never accepted dropped files

## v0.0.8

- Added "Optimize with ImageOptim" checkbox in the Save panel
- After saving, the file is automatically opened in ImageOptim for further optimization
- Preference is persisted and also used for the Overwrite save path
- Feature is hidden entirely when ImageOptim is not installed

## v0.0.7

- Added Copy (Cmd+C) to copy the quantized image to the clipboard
- Added drag-out support: drag the quantized image from the canvas to Finder or other apps
- Added side-by-side split comparison view with draggable divider
- Added `LSHandlerRank` so ImageAlpha appears in Finder's "Open With" menu for PNGs

## v0.0.6

- Checkerboard transparency pattern now adapts to dark mode (dark gray tones instead of bright white)
- Both sidebar thumbnails and main canvas checkerboard respond to appearance changes
- Removed static `photoshop.png` texture in favor of dynamically generated checkerboard
- Fixed bug where dragging a non-image file onto the canvas would incorrectly update the window title

## v0.0.5

- Added 38 unit tests using Swift Testing framework
- Added SwiftLint with project-specific configuration
- Improved code quality: descriptive variable names, reduced duplication, extracted testable functions
- Added `make lint` and `make test` targets
- Added lint and test steps to CI pipeline

## v0.0.4

- Added code signing and notarization support for release builds

## v0.0.3

- Added credits for original author (Kornel Lesiński) in About dialog

## v0.0.2

- Switched distribution from ZIP to DMG with drag-to-Applications installer

## v0.0.1

- Rewritten in Swift (replacing the original Python/PyObjC implementation)
- Modernized for macOS 15+
- Removed Sparkle auto-updater
- Updated to latest pngquant/libimagequant

This release is based on a fork of [ImageAlpha](https://github.com/pornel/ImageAlpha) by Kornel Lesiński.
