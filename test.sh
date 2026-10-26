#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build/module-cache
DESKISLE_SDK="${SDKROOT:-$(xcrun --show-sdk-path)}"
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]] && xcrun swiftc --version 2>&1 | /usr/bin/grep -q 'Swift version 6.3'; then
  DESKISLE_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi
xcrun swiftc -swift-version 5 -sdk "$DESKISLE_SDK" -module-cache-path "$PWD/.build/module-cache" Sources/Models.swift Tests/ModelTests.swift -o .build/ModelTests
.build/ModelTests
