#!/bin/bash
# THE gate (§5): run before declaring work finished. Fails loudly; a step that
# quietly does nothing is indistinguishable from one that worked.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== generate =="
xcodegen generate

echo "== build =="
./scripts/build.sh

echo "== lint =="
swiftlint --strict

echo "== deadcode =="
./scripts/deadcode.sh

echo "== test =="
./scripts/test.sh

echo "gate: green"
