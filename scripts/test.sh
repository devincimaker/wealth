#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="${WEALTH_SIM:-iPhone 17 Pro}"
xcodebuild -project Wealth.xcodeproj -scheme Wealth \
  -destination "platform=iOS Simulator,name=$SIM" \
  -quiet test
