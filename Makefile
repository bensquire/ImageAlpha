PROJECT = ImageAlpha.xcodeproj
SCHEME = ImageAlpha
BUILD_DIR = build
PNGQUANT_DIR = pngquant
VERSION = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)

.PHONY: build debug release archive clean pngquant dmg

build: debug

pngquant:
	cargo build --release --manifest-path $(PNGQUANT_DIR)/imagequant-sys/Cargo.toml

debug:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug build

release:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release build

archive:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-archivePath $(BUILD_DIR)/ImageAlpha.xcarchive archive

dmg: release
	mkdir -p $(BUILD_DIR)
	cp -R $(HOME)/Library/Developer/Xcode/DerivedData/ImageAlpha-*/Build/Products/Release/ImageAlpha.app $(BUILD_DIR)/
	create-dmg \
		--volname "ImageAlpha" \
		--window-pos 200 120 \
		--window-size 600 400 \
		--icon "ImageAlpha.app" 150 200 \
		--app-drop-link 450 200 \
		--no-internet-enable \
		$(BUILD_DIR)/ImageAlpha-v$(VERSION).dmg \
		$(BUILD_DIR)/ImageAlpha.app

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	-rm -rf $(BUILD_DIR)
