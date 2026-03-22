#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_BOARD="armv7-5.4"
TARGET_SUBTARGET="generic-glibc"
TARGET_PACKAGES_DIR="${REPO_ROOT}/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}/packages"
SETUP_INSTALLER="${REPO_ROOT}/installers/setup_armv7hf-5.4.sh"
GLIBC_VERSION="2.27"
LOADER_NAME="ld-linux-armhf.so.3"

usage() {
  cat <<EOF
Usage: $0 <pages-dir> <publish-base-url>
EOF
}

[[ $# -eq 2 ]] || {
  usage >&2
  exit 1
}

PAGES_DIR="$1"
PUBLISH_BASE_URL="${2%/}"
FEED_NAME="armv7hf-k5.4"
FEED_DIR="${PAGES_DIR}/${FEED_NAME}"
INSTALLER_DIR="${FEED_DIR}/installer"

find_opkg() {
  local candidates=(
    "${REPO_ROOT}/staging_dir/target-arm_cortex-a7+neon-vfpv4_glibc-2.27_eabi/root-armv7-5.4/opt/bin/opkg"
    "${REPO_ROOT}/build_dir/target-arm_cortex-a7+neon-vfpv4_glibc-2.27_eabi/linux-armv7-5.4/opkg-"*/.pkgdir/opkg/opt/bin/opkg
    "${REPO_ROOT}/build_dir/target-arm_cortex-a7+neon-vfpv4_glibc-2.27_eabi/linux-armv7-5.4/opkg-"*/ipkg-armv7-5.4/opkg/opt/bin/opkg
  )
  local candidate

  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

[[ -d "${TARGET_PACKAGES_DIR}" ]] || {
  echo "ERROR: package directory not found: ${TARGET_PACKAGES_DIR}" >&2
  exit 1
}

OPKG_BIN="$(find_opkg)" || {
  echo "ERROR: built opkg binary not found" >&2
  exit 1
}

MKHASH_BIN="${REPO_ROOT}/staging_dir/host/bin/mkhash"
[[ -x "${MKHASH_BIN}" ]] || {
  echo "ERROR: mkhash tool not found: ${MKHASH_BIN}" >&2
  exit 1
}

rm -rf "${FEED_DIR}"
mkdir -p "${INSTALLER_DIR}"
: > "${PAGES_DIR}/.nojekyll"

cp -a "${TARGET_PACKAGES_DIR}/." "${FEED_DIR}/"

(
  cd "${FEED_DIR}"
  MKHASH="${MKHASH_BIN}" "${REPO_ROOT}/scripts/ipkg-make-index.sh" . > Packages
  gzip -n -9c Packages > Packages.gz
)

install -m 0755 "${OPKG_BIN}" "${INSTALLER_DIR}/opkg"

cat > "${INSTALLER_DIR}/opkg.conf" <<EOF
src/gz entware ${PUBLISH_BASE_URL}
dest root /
dest ram /opt/tmp
lists_dir ext /opt/var/opkg-lists
option tmp_dir /opt/tmp
arch all 100
arch ${TARGET_BOARD} 160
EOF

cat > "${INSTALLER_DIR}/generic.sh" <<EOF
#!/bin/sh

set -eu

TYPE='generic'
#TYPE='alternative'

unset LD_LIBRARY_PATH
unset LD_PRELOAD

ARCH=${FEED_NAME}
LOADER=${LOADER_NAME}
GLIBC=${GLIBC_VERSION}
REPO="${PUBLISH_BASE_URL}"

echo 'Info: Checking for prerequisites and creating folders...'
if [ -d /opt ]; then
    echo 'Warning: Folder /opt exists!'
else
    mkdir /opt
fi
for folder in bin etc lib/opkg tmp var/lock
do
  if [ -d "/opt/\$folder" ]; then
    echo "Warning: Folder /opt/\$folder exists!"
    echo 'Warning: If something goes wrong please clean /opt folder and try again.'
  else
    mkdir -p /opt/\$folder
  fi
done

echo 'Info: Opkg package manager deployment...'
wget "\${REPO}/installer/opkg" -O /opt/bin/opkg
chmod 755 /opt/bin/opkg
wget "\${REPO}/installer/opkg.conf" -O /opt/etc/opkg.conf

echo 'Info: Basic packages installation...'
/opt/bin/opkg update
if [ \$TYPE = 'alternative' ]; then
  /opt/bin/opkg install busybox
fi
/opt/bin/opkg install entware-opt

chmod 777 /opt/tmp

for file in passwd group shells shadow gshadow; do
  if [ \$TYPE = 'generic' ]; then
    if [ -f /etc/\$file ]; then
      ln -sf /etc/\$file /opt/etc/\$file
    else
      [ -f /opt/etc/\$file.1 ] && cp /opt/etc/\$file.1 /opt/etc/\$file
    fi
  else
    if [ -f /opt/etc/\$file.1 ]; then
      cp /opt/etc/\$file.1 /opt/etc/\$file
    fi
  fi
done

[ -f /etc/localtime ] && ln -sf /etc/localtime /opt/etc/localtime

echo 'Info: Congratulations!'
echo 'Info: If there are no errors above then Entware was successfully initialized.'
echo 'Info: Add /opt/bin & /opt/sbin to \$PATH variable'
echo 'Info: Add "/opt/etc/init.d/rc.unslung start" to startup script for Entware services to start'
if [ \$TYPE = 'alternative' ]; then
  echo 'Info: Use ssh server from Entware for better compatibility.'
fi
echo 'Info: Found a Bug? Please report at https://github.com/pdscomp/Kipware/issues'
EOF
chmod 0755 "${INSTALLER_DIR}/generic.sh"

sed "s|^REPO=.*$|REPO=\"${PUBLISH_BASE_URL}\"|" "${SETUP_INSTALLER}" > "${FEED_DIR}/setup_armv7hf-5.4.sh"
chmod 0755 "${FEED_DIR}/setup_armv7hf-5.4.sh"
cp "${FEED_DIR}/setup_armv7hf-5.4.sh" "${INSTALLER_DIR}/setup_armv7hf-5.4.sh"
