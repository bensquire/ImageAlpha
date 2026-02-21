<div align="center">

# ImageAlpha

**Lossy PNG compression for macOS** — reduce file sizes by applying lossy compression to the alpha channel.

[![macOS](https://img.shields.io/badge/macOS-15%2B-000000?logo=apple&logoColor=white)](https://github.com/bensquire/ImageAlpha/releases)
[![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/license-GPLv3-blue)](https://www.gnu.org/licenses/gpl-3.0.html)
[![CI](https://github.com/bensquire/ImageAlpha/actions/workflows/ci.yml/badge.svg)](https://github.com/bensquire/ImageAlpha/actions/workflows/ci.yml)
[![GitHub release](https://img.shields.io/github/v/release/bensquire/ImageAlpha)](https://github.com/bensquire/ImageAlpha/releases)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/squired)

<br>

<img src="screenshot.png" alt="ImageAlpha screenshot" width="720">

</div>

<br>

## Features

- **Lossy alpha compression** powered by pngquant/libimagequant
- **Real-time preview** — see before/after as you adjust settings
- **Adjustable colors and dithering** for fine-tuned control
- **Side-by-side comparison** — split view with draggable divider to compare original and quantized
- **Copy & drag export** — Cmd+C to copy, or drag the image directly to Finder or other apps
- **Background previews** — checkerboard, solid color, and image textures
- **File size savings** displayed before saving
- **Open With support** — right-click any PNG in Finder to open in ImageAlpha

## Download

Pre-built binaries are available on the [**Releases**](https://github.com/bensquire/ImageAlpha/releases) page.

## Build from source

### Prerequisites

- Xcode 16+
- Rust toolchain (`cargo`) — install via [rustup.rs](https://rustup.rs/)

### Clone and build

```sh
git clone --recursive https://github.com/bensquire/ImageAlpha.git
cd ImageAlpha
make pngquant   # build libimagequant (Rust)
make release     # build the app (Xcode)
```

The built app will be at `~/Library/Developer/Xcode/DerivedData/ImageAlpha-*/Build/Products/Release/ImageAlpha.app`.

To create a distributable DMG:

```sh
brew install create-dmg
make dmg
```

## Credits

- [Kornel Lesiński](https://kornel.ski/) — original ImageAlpha author
- [pngquant](https://pngquant.org/) and [libimagequant](https://github.com/ImageOptim/libimagequant) — the quantization engine
- [ManyTextures](https://manytextures.com/) — tileable background images

## License

This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).
