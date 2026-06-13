APP      := Lumo
BUNDLE   := $(APP).app
EXEC     := $(BUNDLE)/Contents/MacOS/$(APP)
PLIST    := $(BUNDLE)/Contents/Info.plist
LSREG    := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
SIGN_ID  := Lumo Self-Signed

.PHONY: build run install reload clean

# Sign every build with a stable self-signed identity so macOS TCC grants
# (Spotify automation, Bluetooth, Location) persist across rebuilds.
build: $(EXEC) $(PLIST)
	@codesign --force --sign "$(SIGN_ID)" $(BUNDLE) && echo "[codesign] $(BUNDLE) signed with '$(SIGN_ID)'"

$(EXEC): Sources/*.swift
	@mkdir -p $(BUNDLE)/Contents/MacOS
	swiftc -O -swift-version 5 Sources/*.swift -o $(EXEC)

$(PLIST): Info.plist
	@mkdir -p $(BUNDLE)/Contents
	cp Info.plist $(PLIST)
	@$(LSREG) -f $(BUNDLE) 2>/dev/null || true

# Build, kill any running instance, relaunch (registers URL scheme too).
run: build
	@killall $(APP) 2>/dev/null || true
	@open $(BUNDLE)
	@echo "Lumo running. Try:  open 'lumo://tab/music'"

# Rebuild + relaunch in one step during development.
reload: run

install: build
	@cp -R $(BUNDLE) /Applications/
	@$(LSREG) -f /Applications/$(BUNDLE) 2>/dev/null || true
	@echo "Installed to /Applications/$(BUNDLE)"

clean:
	@rm -rf $(BUNDLE)
	@echo "cleaned"
