PROJECT = ImageAlpha.xcodeproj
SCHEME = ImageAlpha
BUILD_DIR = build
PNGQUANT_DIR = pngquant
VERSION = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
DEVELOPMENT_TEAM ?=
APP_PATH = $(BUILD_DIR)/ImageAlpha.app
DMG_PATH = $(BUILD_DIR)/ImageAlpha-v$(VERSION).dmg

.PHONY: build debug release archive clean pngquant sign notarize dmg publish test lint

build: debug

pngquant:
	cargo build --release --manifest-path $(PNGQUANT_DIR)/imagequant-sys/Cargo.toml

debug:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug build

release:
ifdef DEVELOPMENT_TEAM
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) build
else
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
endif

archive:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-archivePath $(BUILD_DIR)/ImageAlpha.xcarchive archive

sign:
	codesign --force --sign "Developer ID Application" \
		--entitlements ImageAlpha.entitlements \
		--options runtime \
		--timestamp \
		$(APP_PATH)

notarize:
	xcrun notarytool submit $(DMG_PATH) \
		--apple-id "$(NOTARY_APPLE_ID)" \
		--password "$(NOTARY_PASSWORD)" \
		--team-id "$(APPLE_TEAM_ID)" \
		--wait
	xcrun stapler staple $(DMG_PATH)

dmg: release
	mkdir -p $(BUILD_DIR)
	cp -R $(HOME)/Library/Developer/Xcode/DerivedData/ImageAlpha-*/Build/Products/Release/ImageAlpha.app $(BUILD_DIR)/
ifdef DEVELOPMENT_TEAM
	$(MAKE) sign
endif
	rm -f $(DMG_PATH)
	create-dmg \
		--volname "ImageAlpha" \
		--window-pos 200 120 \
		--window-size 600 400 \
		--icon "ImageAlpha.app" 150 200 \
		--app-drop-link 450 200 \
		--no-internet-enable \
		$(DMG_PATH) \
		$(APP_PATH)

publish: dmg notarize
	gh release create "v$(VERSION)" $(DMG_PATH) --generate-notes || \
	gh release upload "v$(VERSION)" $(DMG_PATH) --clobber

lint:
	swiftlint lint --strict

test: pngquant
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	-rm -rf $(BUILD_DIR)
