APP_NAME    := Awake
BUNDLE_ID   := com.awake.app
VERSION     := 1.2
BUILD_DIR   := build
APP_BUNDLE  := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR := /Applications

SDK         := $(shell xcrun --show-sdk-path)
ARCH        := $(shell uname -m)
TARGET      := $(ARCH)-apple-macosx13.0
SWIFTC      := $(shell xcrun --find swiftc)

SOURCES     := Awake/AwakeApp.swift Awake/AppState.swift Awake/AppMenu.swift Awake/ScheduleSettingsView.swift Awake/DimOverlay.swift
FRAMEWORKS  := -framework SwiftUI -framework AppKit -framework IOKit -framework ServiceManagement

.PHONY: all dev build test open close clean install uninstall reinstall \
        _bundle_dev _bundle_release _scaffold

all: dev

test:
	swift test --disable-sandbox

dev: close clean _bundle_dev
	open "$(APP_BUNDLE)"

build: _bundle_release

open: close _bundle_release
	open "$(APP_BUNDLE)"

close:
	-pkill -x "$(APP_NAME)"

clean:
	rm -rf "$(BUILD_DIR)"

install: close _bundle_release
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -r "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"
	open "$(INSTALL_DIR)/$(APP_NAME).app"

uninstall: close
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"

reinstall: uninstall install

_scaffold:
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	sed \
		-e 's/$$(EXECUTABLE_NAME)/$(APP_NAME)/g' \
		-e 's/$$(PRODUCT_BUNDLE_IDENTIFIER)/$(BUNDLE_ID)/g' \
		-e 's/$$(PRODUCT_NAME)/$(APP_NAME)/g' \
		-e 's/$$(MARKETING_VERSION)/$(VERSION)/g' \
		-e 's/$$(CURRENT_PROJECT_VERSION)/1/g' \
		-e 's/$$(MACOSX_DEPLOYMENT_TARGET)/13.0/g' \
		Awake/Info.plist > "$(APP_BUNDLE)/Contents/Info.plist"

_bundle_dev: _scaffold
	$(SWIFTC) \
		-sdk "$(SDK)" \
		-target $(TARGET) \
		$(FRAMEWORKS) \
		-Onone -g \
		-o "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)" \
		$(SOURCES)

_bundle_release: _scaffold
	$(SWIFTC) \
		-sdk "$(SDK)" \
		-target $(TARGET) \
		$(FRAMEWORKS) \
		-O \
		-o "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)" \
		$(SOURCES)
