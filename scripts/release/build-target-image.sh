#!/usr/bin/env bash
# Build one Kipware release install image target.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

usage() {
  cat <<'EOF'
Usage: build-target-image.sh [--target cc1|cc2] [--tag YYYY-MM-DD]

Environment variables:
  TARGET_ID       Target id, e.g. cc1 or cc2 (overridden by --target)
  GITHUB_TAG      Release tag/date (overridden by --tag)
  REPO_BASE_URL   Kipware feed base URL
  PACKAGE_LIST    Package manifest path
  OUT_DIR         Output directory for tarball
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { echo "ERROR: --target requires an argument" >&2; exit 2; }
      TARGET_ID="$2"
      shift 2
      ;;
    --tag)
      [[ $# -ge 2 ]] || { echo "ERROR: --tag requires an argument" >&2; exit 2; }
      GITHUB_TAG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

TARGET_ID="${TARGET_ID:?TARGET_ID is required}"
GITHUB_TAG="${GITHUB_TAG:?GITHUB_TAG is required}"
REPO_BASE_URL="${REPO_BASE_URL:-https://pdscomp.github.io/Kipware/kip/armv7hf-k5.4}"
PACKAGE_LIST="${PACKAGE_LIST:-${REPO_ROOT}/release/kipware-install-packages.txt}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/dist}"
TARGET_CONFIG="${REPO_ROOT}/release/targets/${TARGET_ID}.env"

[[ "$(id -u)" = 0 ]] || { echo "ERROR: this script must run as root" >&2; exit 1; }
[[ -f "${TARGET_CONFIG}" ]] || { echo "ERROR: target config not found: ${TARGET_CONFIG}" >&2; exit 1; }

# shellcheck disable=SC1090
source "${TARGET_CONFIG}"
: "${KIP_TARGET:?KIP_TARGET is required in ${TARGET_CONFIG}}"
: "${TAR_ROOTS:?TAR_ROOTS is required in ${TARGET_CONFIG}}"
# shellcheck source=scripts/release/lib-install-image.sh
source "${SCRIPT_DIR}/lib-install-image.sh"

validate_tag "${GITHUB_TAG}"
preflight_packages_in_index "${REPO_BASE_URL}" "${PACKAGE_LIST}"
prepare_kip_symlink "${KIP_TARGET}"
download_and_run_generic_installer "${REPO_BASE_URL}"
write_profile /kip/profile-kipware.sh
# shellcheck disable=SC1091
source /kip/profile-kipware.sh
install_package_manifest "${PACKAGE_LIST}"
# shellcheck disable=SC2086 # TAR_ROOTS intentionally contains a whitespace-separated root list from target config.
fix_permissions /kip ${TAR_ROOTS}
# shellcheck disable=SC2086 # TAR_ROOTS intentionally contains a whitespace-separated root list from target config.
create_tarball "${OUT_DIR}/kipware-${TARGET_ID}-${GITHUB_TAG}.tar.gz" ${TAR_ROOTS}
verify_tarball "${OUT_DIR}/kipware-${TARGET_ID}-${GITHUB_TAG}.tar.gz" "${KIP_TARGET}"
