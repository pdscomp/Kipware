#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ID=cc1 exec "${SCRIPT_DIR}/build-target-image.sh" "$@"
