PROJECT = ImageAlpha.xcodeproj
SCHEME = ImageAlpha
BUILD_DIR = build
PNGQUANT_DIR = pngquant
VERSION = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)

.PHONY: build debug release archive clean pngquant zip

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

zip: release
	mkdir -p $(BUILD_DIR)
	cp -R $(HOME)/Library/Developer/Xcode/DerivedData/ImageAlpha-*/Build/Products/Release/ImageAlpha.app $(BUILD_DIR)/
	cd $(BUILD_DIR) && zip -r ImageAlpha-v$(VERSION).zip ImageAlpha.app

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	-rm -rf $(BUILD_DIR)
