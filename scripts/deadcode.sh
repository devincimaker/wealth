#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
periphery scan --quiet --strict
