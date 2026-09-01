#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project Wealth.xcodeproj -scheme Wealth \
  -destination 'generic/platform=iOS Simulator' \
  -quiet build
