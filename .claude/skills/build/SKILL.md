---
name: build
description: Build ImageAlpha from the command line — libimagequant with cargo, the Debug or Release app with xcodebuild, the test suite or a single test, swift-format, cleaning — and what the release path (sign, DMG, notarize, GitHub release) does. Use when asked to build ImageAlpha, run its tests, lint or format it, reproduce a CI failure, or explain how a release is made. To launch the app and drive its UI, use run-imagealpha.
---

# Building ImageAlpha

ImageAlpha is an Xcode project (`ImageAlpha.xcodeproj`, scheme `ImageAlpha`)
that links libimagequant, a Rust library in the `pngquant` submodule, as a
static archive. The `Makefile` wraps both. Everything here runs from the repo
root.

## Prerequisites

| Tool | Why | Checked here |
|---|---|---|
| Xcode | The app targets macOS 15, Swift 5 language mode, arm64 only | Xcode 26.6 |
| Rust (`cargo`) | Builds libimagequant | cargo 1.93.0 |
| `pngquant` submodule | libimagequant's source | `git submodule status pngquant` starts with a space, not `-` |
| swift-format (in Xcode's toolchain, as `swift format`) | `make lint`, `make format`, the format hook | 6.3.0 |
| create-dmg, gh (Homebrew) | Only for the release path | — |

A fresh clone needs `git submodule update --init` before anything builds.

## libimagequant

```bash
make pngquant
```

Builds `pngquant/target/release/libimagequant_sys.a` with thin LTO, which the
Xcode project finds through `LIBRARY_SEARCH_PATHS`. Up to date, it takes 0.1 s.
Cargo's "profiles for the non root package will be ignored" warning is noise.
`make test` runs this first; a Debug build through the run-imagealpha driver
does too.

## The Debug app

```bash
make pngquant
xcodebuild -project ImageAlpha.xcodeproj -scheme ImageAlpha -configuration Debug \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build -quiet
```

`.claude/skills/run-imagealpha/driver.sh build` runs the same two steps and
prints the app's path. Signing is ad hoc because the project signs manually
with `$(DEVELOPMENT_TEAM)`: `make debug` (and `make build`, its alias) fails
locally with "Signing for "ImageAlpha" requires selecting either a development
team or a provisioning profile". A clean Debug build takes about 8 s once
libimagequant is built.

The product is
`~/Library/Developer/Xcode/DerivedData/ImageAlpha-*/Build/Products/Debug/ImageAlpha.app`
(about 35 MB, mostly the debug dylib). Open it with
`open "$(ls -d ~/Library/Developer/Xcode/DerivedData/ImageAlpha-*/Build/Products/Debug/ImageAlpha.app)"`,
or use the run-imagealpha skill to launch and drive it. The Debug build has the
release bundle id, `net.pornel.ImageAlpha`, so it shares preferences with any
installed copy.

## The Release app

```bash
make release
```

Builds the Release configuration (`release.xcconfig`: `-Osize`, dead-code
stripping, stripped symbols), ad-hoc signed when `DEVELOPMENT_TEAM` is unset.
This is what CI builds. The app is about 1.3 MB: a 932 KB executable with
libimagequant linked in, 276 KB of textures and a 76 KB icon, and no
`Frameworks` folder.

## Tests

```bash
make test
```

Runs `make pngquant`, then `xcodebuild … -configuration Debug test`, ad-hoc
signed. The suite is Swift Testing: 100 tests in 9 suites, 6–10 s warm, of
which the tests themselves take 0.3 s. The test host is the app itself
(`TEST_HOST`), so tests run inside ImageAlpha and its sandbox container.
`Unable to get synchronousRemoteObjectProxy … com.apple.linkd.autoShortcut`
lines in the log are system noise.

One suite or one test (Swift Testing names carry their parentheses):

```bash
xcodebuild -project ImageAlpha.xcodeproj -scheme ImageAlpha -configuration Debug \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test \
  -only-testing:'ImageAlphaTests/QuantizerTests/producesIndexedColorTypePNG()'
# a whole suite: -only-testing:ImageAlphaTests/QuantizerTests
```

One test takes about 3 s, nearly all of it the build check. Run `make pngquant`
first if libimagequant has never been built.

## Lint and format

```bash
make lint      # swift format lint --strict: 0.2 s
make format    # swift format in place: *.swift, Views, ImageAlphaTests
```

swift-format and `.swift-format` decide formatting and are the only linter
(see the `quality-formatting-is-the-tools` rule). Lines are 110 columns. The
hooks in `.claude/hooks/` format each Swift file as it is edited and then
report any line still over 110 columns. `.githooks/pre-commit` runs `make lint`
and `make test`; it is on once `git config core.hooksPath .githooks` has been
set.

## What CI runs

`.github/workflows/ci.yml`, on pushes and pull requests to `master`
(macOS 26 with Xcode 26.6 pinned, so its swift-format matches a local Xcode
26.6; submodules checked out): `make lint`,
install Rust, `make pngquant`, `make release`, `make test`. The same locally:

```bash
make lint && make release && make test
```

## Cleaning

`make clean` runs `xcodebuild clean` and deletes `build/` (where the DMG and
the copied release app go). It leaves libimagequant alone;
`cargo clean --manifest-path pngquant/imagequant-sys/Cargo.toml` removes that.

## The release path

Run only when the user asks for a release. The version is
`CFBundleShortVersionString` in `Info.plist`, and `CHANGELOG.md` gains its
entry at release time.

- **`.github/workflows/release.yml`** runs on a pushed `v*` tag: builds
  libimagequant, imports the Developer ID certificate into a temporary
  keychain, runs `make dmg` with `DEVELOPMENT_TEAM` set, then `make notarize`,
  then `gh release create` with the DMG.
- **`make dmg`** builds Release, copies the app from DerivedData into `build/`,
  signs it (`make sign`: Developer ID, hardened runtime, timestamp,
  `ImageAlpha.entitlements`) when `DEVELOPMENT_TEAM` is set, and makes
  `build/ImageAlpha-v<version>.dmg` with create-dmg.
- **`make notarize`** submits the DMG with `notarytool --wait` (needs
  `NOTARY_APPLE_ID`, `NOTARY_PASSWORD`, `APPLE_TEAM_ID`) and staples it.
- **`make publish`** does `dmg`, `notarize` and then creates the GitHub
  release, or uploads to it if it exists.
