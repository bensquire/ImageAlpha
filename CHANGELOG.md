# Changelog

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
