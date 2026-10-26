#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build/module-cache dist/DeskIsle.app/Contents/MacOS dist/DeskIsle.app/Contents/Resources
ARCH="$(uname -m)"
# SDKROOT can override the default; use the installed matching SDK on this host.
DESKISLE_SDK="${SDKROOT:-$(xcrun --show-sdk-path)}"
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]] && xcrun swiftc --version 2>&1 | /usr/bin/grep -q 'Swift version 6.3'; then
  DESKISLE_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi
xcrun swiftc -swift-version 5 -O -sdk "$DESKISLE_SDK" -target "${ARCH}-apple-macosx14.0" \
  -module-cache-path "$PWD/.build/module-cache" \
  Sources/Models.swift Sources/Store.swift Sources/WidgetViews.swift Sources/MainView.swift Sources/Application.swift Sources/SmokeChecks.swift Sources/main.swift \
  -o dist/DeskIsle.app/Contents/MacOS/DeskIsle -framework AppKit -framework SwiftUI -framework UniformTypeIdentifiers
cp Resources/Info.plist dist/DeskIsle.app/Contents/Info.plist
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns dist/DeskIsle.app/Contents/Resources/
  /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' dist/DeskIsle.app/Contents/Info.plist
fi
codesign --force --deep --sign - dist/DeskIsle.app
print "已构建：$PWD/dist/DeskIsle.app"
