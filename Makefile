TARGET = alacritty

ASSETS_DIR = extra
RELEASE_DIR = target/release
MANPAGE = $(ASSETS_DIR)/man/alacritty.1.scd
MANPAGE-MSG = $(ASSETS_DIR)/man/alacritty-msg.1.scd
MANPAGE-CONFIG = $(ASSETS_DIR)/man/alacritty.5.scd
MANPAGE-CONFIG-BINDINGS = $(ASSETS_DIR)/man/alacritty-bindings.5.scd
MANPAGE-ESCAPES = $(ASSETS_DIR)/man/alacritty-escapes.7.scd
TERMINFO = $(ASSETS_DIR)/alacritty.info
COMPLETIONS_DIR = $(ASSETS_DIR)/completions
COMPLETIONS = $(COMPLETIONS_DIR)/_alacritty \
	$(COMPLETIONS_DIR)/alacritty.bash \
	$(COMPLETIONS_DIR)/alacritty.fish

# App name; the binary gets it as BRAND_NAME.
BRAND ?= Temeritty
APP_NAME = $(BRAND).app
BUNDLE_ID ?= net.fastfin.temeritty
APP_TEMPLATE = $(ASSETS_DIR)/osx/Temeritty.app
APP_DIR = $(RELEASE_DIR)/osx
APP_BINARY = $(RELEASE_DIR)/$(TARGET)
APP_BINARY_DIR = $(APP_DIR)/$(APP_NAME)/Contents/MacOS
APP_EXTRAS_DIR = $(APP_DIR)/$(APP_NAME)/Contents/Resources
APP_COMPLETIONS_DIR = $(APP_EXTRAS_DIR)/completions
APP_FRAMEWORKS_DIR = $(APP_DIR)/$(APP_NAME)/Contents/Frameworks
# Built by extra/osx/build-angle.sh.
ANGLE_DIR = target/angle

DMG_NAME = $(BRAND).dmg
DMG_DIR = $(RELEASE_DIR)/osx

vpath $(TARGET) $(RELEASE_DIR)
vpath $(APP_NAME) $(APP_DIR)
vpath $(DMG_NAME) $(APP_DIR)

all: help

help: ## Print this help message
	@grep -E '^[a-zA-Z._-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

binary: $(TARGET)-native ## Build a release binary
binary-universal: $(TARGET)-universal ## Build a universal release binary
$(TARGET)-native:
	BRAND_NAME="$(BRAND)" MACOSX_DEPLOYMENT_TARGET="13.0" cargo build --release
$(TARGET)-universal:
	BRAND_NAME="$(BRAND)" MACOSX_DEPLOYMENT_TARGET="13.0" cargo build --release --target=x86_64-apple-darwin
	BRAND_NAME="$(BRAND)" MACOSX_DEPLOYMENT_TARGET="13.0" cargo build --release --target=aarch64-apple-darwin
	@lipo target/{x86_64,aarch64}-apple-darwin/release/$(TARGET) -create -output $(APP_BINARY)

angle: angle-native ## Build ANGLE for cargo run
	@mkdir -p target/debug $(RELEASE_DIR)
	@cp -f $(ANGLE_DIR)/native/*.dylib target/debug
	@cp -f $(ANGLE_DIR)/native/*.dylib $(RELEASE_DIR)
angle-native:
	@sh $(ASSETS_DIR)/osx/build-angle.sh $(ANGLE_DIR)/native
angle-universal:
	@sh $(ASSETS_DIR)/osx/build-angle.sh $(ANGLE_DIR)/universal arm64 x64

app: $(APP_NAME)-native ## Create the app
app-universal: $(APP_NAME)-universal ## Create a universal app
$(APP_NAME)-%: $(TARGET)-% angle-%
	@mkdir -p $(APP_BINARY_DIR)
	@mkdir -p $(APP_EXTRAS_DIR)
	@mkdir -p $(APP_COMPLETIONS_DIR)
	@mkdir -p $(APP_FRAMEWORKS_DIR)
	@scdoc < $(MANPAGE) | gzip -c > $(APP_EXTRAS_DIR)/alacritty.1.gz
	@scdoc < $(MANPAGE-MSG) | gzip -c > $(APP_EXTRAS_DIR)/alacritty-msg.1.gz
	@scdoc < $(MANPAGE-CONFIG) | gzip -c > $(APP_EXTRAS_DIR)/alacritty.5.gz
	@scdoc < $(MANPAGE-CONFIG-BINDINGS) | gzip -c > $(APP_EXTRAS_DIR)/alacritty-bindings.5.gz
	@scdoc < $(MANPAGE-ESCAPES) | gzip -c > $(APP_EXTRAS_DIR)/alacritty-escapes.7.gz
	@tic -xe alacritty,alacritty-direct -o $(APP_EXTRAS_DIR) $(TERMINFO)
	@cp -fRp $(APP_TEMPLATE)/Contents $(APP_DIR)/$(APP_NAME)
	@cp -fp $(APP_BINARY) "$(APP_BINARY_DIR)/$(BRAND)"
	@sed -i '' 's/Temeritty/$(BRAND)/g' "$(APP_DIR)/$(APP_NAME)/Contents/Info.plist"
	@plutil -replace CFBundleIdentifier -string "$(BUNDLE_ID)" "$(APP_DIR)/$(APP_NAME)/Contents/Info.plist"
	@cp -fp $(COMPLETIONS) $(APP_COMPLETIONS_DIR)
	@cp -fp $(ANGLE_DIR)/$*/libEGL.dylib $(ANGLE_DIR)/$*/libGLESv2.dylib $(APP_FRAMEWORKS_DIR)
	@cp -fp $(ANGLE_DIR)/$*/THIRD-PARTY-NOTICES.txt $(APP_EXTRAS_DIR)
	@touch -r "$(APP_BINARY)" "$(APP_DIR)/$(APP_NAME)"
	@codesign --remove-signature "$(APP_DIR)/$(APP_NAME)"
	@codesign --force --deep --sign - "$(APP_DIR)/$(APP_NAME)"
	@echo "Created '$(APP_NAME)' in '$(APP_DIR)'"

dmg: $(DMG_NAME)-native ## Create a disk image
dmg-universal: $(DMG_NAME)-universal ## Create a universal disk image
$(DMG_NAME)-%: $(APP_NAME)-%
	@echo "Packing disk image..."
	@ln -sf /Applications $(DMG_DIR)/Applications
	@hdiutil create $(DMG_DIR)/$(DMG_NAME) \
		-volname "$(BRAND)" \
		-fs HFS+ \
		-srcfolder $(APP_DIR) \
		-ov -format UDZO
	@echo "Packed '$(APP_NAME)' in '$(APP_DIR)'"

install: $(INSTALL)-native ## Mount disk image
install-universal: $(INSTALL)-native ## Mount universal disk image
$(INSTALL)-%: $(DMG_NAME)-%
	@open $(DMG_DIR)/$(DMG_NAME)

.PHONY: angle angle-native angle-universal app binary clean dmg install $(TARGET) $(TARGET)-universal

clean: ## Remove all build artifacts
	@cargo clean
