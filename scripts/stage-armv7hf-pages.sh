#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

find_target_packages_dir() {
  local candidate

  while IFS= read -r candidate; do
    [[ -n "${candidate}" ]] || continue
    if find "${candidate}" -maxdepth 1 -type f -name '*.ipk' -print -quit | grep -q .; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done < <(find "${REPO_ROOT}/bin/targets" -type d -path '*/packages' | sort)

  return 1
}

find_opkg() {
  local candidate

  while IFS= read -r candidate; do
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done < <(find "${REPO_ROOT}" \
    \( -path '*/kip/bin/opkg' -o -path '*/ipkg-*/opkg/kip/bin/opkg' \) \
    -type f | sort)

  return 1
}

TARGET_PACKAGES_DIR="$(find_target_packages_dir)" || {
  echo "ERROR: built package directory not found under ${REPO_ROOT}/bin/targets" >&2
  exit 1
}

TARGET_BOARD="$(basename "$(dirname "$(dirname "${TARGET_PACKAGES_DIR}")")")"

[[ -d "${TARGET_PACKAGES_DIR}" ]] || {
  echo "ERROR: package directory not found: ${TARGET_PACKAGES_DIR}" >&2
  exit 1
}

OPKG_BIN="$(find_opkg)" || {
  echo "ERROR: built opkg binary not found" >&2
  exit 1
}

ENTWARE_OPT_FILES_DIR="${REPO_ROOT}/feeds/rtndev/entware-opt/files"
[[ -d "${ENTWARE_OPT_FILES_DIR}" ]] || {
  echo "ERROR: entware-opt files directory not found: ${ENTWARE_OPT_FILES_DIR}" >&2
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

find "${TARGET_PACKAGES_DIR}" -maxdepth 1 -type f -name '*.ipk' -exec cp -a {} "${FEED_DIR}/" \;

(
  cd "${FEED_DIR}"
  MKHASH="${MKHASH_BIN}" "${REPO_ROOT}/scripts/ipkg-make-index.sh" . > Packages
  gzip -n -9c Packages > Packages.gz
)

install -m 0755 "${OPKG_BIN}" "${INSTALLER_DIR}/opkg"

cat > "${INSTALLER_DIR}/opkg.conf" <<EOF
src/gz entware ${PUBLISH_BASE_URL}
dest root /
dest ram /kip/tmp
lists_dir ext /kip/var/opkg-lists
option tmp_dir /kip/tmp
arch all 100
arch ${TARGET_BOARD} 160
EOF

sed 's|/kip/bin/find|find|' "${ENTWARE_OPT_FILES_DIR}/rc.unslung" > "${INSTALLER_DIR}/rc.unslung"
chmod 0755 "${INSTALLER_DIR}/rc.unslung"
install -m 0644 "${ENTWARE_OPT_FILES_DIR}/rc.func" "${INSTALLER_DIR}/rc.func"
install -m 0755 "${ENTWARE_OPT_FILES_DIR}/profile" "${INSTALLER_DIR}/profile"
install -m 0644 "${ENTWARE_OPT_FILES_DIR}/passwd.1" "${INSTALLER_DIR}/passwd.1"
install -m 0644 "${ENTWARE_OPT_FILES_DIR}/group.1" "${INSTALLER_DIR}/group.1"
install -m 0644 "${ENTWARE_OPT_FILES_DIR}/shells.1" "${INSTALLER_DIR}/shells.1"
install -m 0644 "${ENTWARE_OPT_FILES_DIR}/.profile" "${INSTALLER_DIR}/dot-profile"
install -m 0644 "${ENTWARE_OPT_FILES_DIR}/.inputrc" "${INSTALLER_DIR}/dot-inputrc"

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
if [ -d /kip ]; then
    echo 'Warning: Folder /kip exists!'
else
    mkdir /kip
fi
for folder in bin etc lib/opkg tmp var/lock
do
  if [ -d "/kip/\$folder" ]; then
    echo "Warning: Folder /kip/\$folder exists!"
    echo 'Warning: If something goes wrong please clean /kip folder and try again.'
  else
    mkdir -p /kip/\$folder
  fi
done

echo 'Info: Opkg package manager deployment...'
wget "\${REPO}/installer/opkg" -O /kip/bin/opkg
chmod 755 /kip/bin/opkg
wget "\${REPO}/installer/opkg.conf" -O /kip/etc/opkg.conf

echo 'Info: Basic packages installation...'
/kip/bin/opkg update
if [ \$TYPE = 'alternative' ]; then
  /kip/bin/opkg install busybox
fi
/kip/bin/opkg install entware-release entware-upgrade

chmod 777 /kip/tmp

echo 'Info: Installing bootstrap files...'
mkdir -p /kip/etc/init.d /kip/etc/skel /kip/home /kip/root /kip/sbin /kip/share /kip/usr /kip/var/log /kip/var/run
wget "\${REPO}/installer/rc.unslung" -O /kip/etc/init.d/rc.unslung
chmod 755 /kip/etc/init.d/rc.unslung
wget "\${REPO}/installer/rc.func" -O /kip/etc/init.d/rc.func
chmod 644 /kip/etc/init.d/rc.func
wget "\${REPO}/installer/profile" -O /kip/etc/profile
chmod 755 /kip/etc/profile
wget "\${REPO}/installer/passwd.1" -O /kip/etc/passwd.1
wget "\${REPO}/installer/group.1" -O /kip/etc/group.1
wget "\${REPO}/installer/shells.1" -O /kip/etc/shells.1
wget "\${REPO}/installer/dot-profile" -O /kip/etc/skel/.profile
cp /kip/etc/skel/.profile /kip/root/.profile
wget "\${REPO}/installer/dot-inputrc" -O /kip/etc/skel/.inputrc
cp /kip/etc/skel/.inputrc /kip/root/.inputrc
: > /kip/etc/ld.so.conf

for fw_cmd in sbin/ifconfig sbin/route sbin/ip bin/netstat bin/sh bin/ash; do
  if [ -f "/\${fw_cmd}" ] && [ ! -f "/kip/\${fw_cmd}" ]; then
    ln -s "/\${fw_cmd}" "/kip/\${fw_cmd}"
  fi
done

for file in passwd group shells shadow gshadow; do
  if [ \$TYPE = 'generic' ]; then
    if [ -f /etc/\$file ]; then
      ln -sf /etc/\$file /kip/etc/\$file
    else
      [ -f /kip/etc/\$file.1 ] && cp /kip/etc/\$file.1 /kip/etc/\$file
    fi
  else
    if [ -f /kip/etc/\$file.1 ]; then
      cp /kip/etc/\$file.1 /kip/etc/\$file
    fi
  fi
done

[ -f /etc/localtime ] && ln -sf /etc/localtime /kip/etc/localtime

echo 'Info: Congratulations!'
echo 'Info: If there are no errors above then Entware was successfully initialized.'
echo 'Info: Add /kip/bin & /kip/sbin to \$PATH variable'
echo 'Info: Add "/kip/etc/init.d/rc.unslung start" to startup script for Entware services to start'
if [ \$TYPE = 'alternative' ]; then
  echo 'Info: Use ssh server from Entware for better compatibility.'
fi
echo 'Info: Found a Bug? Please report at https://github.com/pdscomp/Kipware/issues'
EOF
chmod 0755 "${INSTALLER_DIR}/generic.sh"

sed "s|^REPO=.*$|REPO=\"${PUBLISH_BASE_URL}\"|" "${SETUP_INSTALLER}" > "${FEED_DIR}/setup_armv7hf-5.4.sh"
chmod 0755 "${FEED_DIR}/setup_armv7hf-5.4.sh"
cp "${FEED_DIR}/setup_armv7hf-5.4.sh" "${INSTALLER_DIR}/setup_armv7hf-5.4.sh"

python3 "${REPO_ROOT}/scripts/gen-index.py" tree "${PAGES_DIR}" "${FEED_NAME}"
